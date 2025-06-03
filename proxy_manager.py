#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Gate.io 监控系统代理管理模块
功能：
1. 支持VLESS URI格式代理配置
2. 支持代理轮换和负载均衡
3. 集成本地sing-box/v2ray客户端配置
4. 提供HTTP/SOCKS代理接口
"""

import os
import json
import time
import random
import logging
import requests
import subprocess
import threading
import re
import base64
import urllib.parse
from urllib.parse import urlparse, parse_qs
from requests.exceptions import RequestException, ProxyError, Timeout
from http.cookiejar import LWPCookieJar
from collections import defaultdict

try:
    from fake_useragent import UserAgent
    HAS_FAKE_UA = True
except ImportError:
    HAS_FAKE_UA = False

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("proxy_manager.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("gate_proxy_manager")

class VLESSProxy:
    """VLESS代理配置类"""
    
    def __init__(self, uri=None):
        """初始化VLESS代理配置
        
        Args:
            uri: VLESS URI格式的代理配置
        """
        self.protocol = "vless"
        self.user_id = ""
        self.address = ""
        self.port = 443
        self.params = {}
        self.tag = ""
        self.local_port = None
        self.process = None
        
        if uri:
            self.parse_uri(uri)
    
    def parse_uri(self, uri):
        """解析VLESS URI
        
        Args:
            uri: VLESS URI格式的代理配置
            
        Example:
            vless://aa05ee3d-ea0f-49e5-8692-4c4f69797110@ty.fk69.top:2026/?type=tcp&encryption=none&flow=xtls-rprx-vision&sni=www.cloudflare.com&fp=chrome&security=reality&pbk=8KlmgUWuITzjG-lpUyLHAXRDf7vQ6HU1OV-TGvHR7BY&sid=#台湾省动态
        """
        try:
            # 检查URI格式
            if not uri.startswith("vless://"):
                raise ValueError("不是有效的VLESS URI")
            
            # 移除协议前缀
            uri = uri[8:]
            
            # 分离标签部分
            if "#" in uri:
                uri, tag = uri.split("#", 1)
                self.tag = urllib.parse.unquote(tag)
            
            # 分离用户ID和服务器地址
            if "@" in uri:
                user_id, server = uri.split("@", 1)
                self.user_id = user_id
            else:
                server = uri
            
            # 分离服务器地址和参数
            if "/?" in server:
                server, params_str = server.split("/?", 1)
                # 解析参数
                self.params = dict(urllib.parse.parse_qsl(params_str))
            
            # 分离地址和端口
            if ":" in server:
                address, port = server.split(":", 1)
                self.address = address
                self.port = int(port)
            else:
                self.address = server
            
            logger.info(f"成功解析VLESS URI: {self.address}:{self.port}, 标签: {self.tag}")
            return True
        
        except Exception as e:
            logger.error(f"解析VLESS URI失败: {e}")
            return False
    
    def to_v2ray_config(self, local_port=1080, local_address="127.0.0.1"):
        """转换为v2ray配置
        
        Args:
            local_port: 本地代理端口
            local_address: 本地代理地址
            
        Returns:
            dict: v2ray配置字典
        """
        config = {
            "log": {
                "loglevel": "warning"
            },
            "inbounds": [
                {
                    "port": local_port,
                    "listen": local_address,
                    "protocol": "socks",
                    "settings": {
                        "udp": True
                    }
                },
                {
                    "port": local_port + 1,
                    "listen": local_address,
                    "protocol": "http"
                }
            ],
            "outbounds": [
                {
                    "protocol": "vless",
                    "settings": {
                        "vnext": [
                            {
                                "address": self.address,
                                "port": self.port,
                                "users": [
                                    {
                                        "id": self.user_id,
                                        "encryption": self.params.get("encryption", "none"),
                                        "flow": self.params.get("flow", "")
                                    }
                                ]
                            }
                        ]
                    },
                    "streamSettings": {
                        "network": self.params.get("type", "tcp"),
                        "security": self.params.get("security", "none")
                    },
                    "tag": "proxy"
                },
                {
                    "protocol": "freedom",
                    "settings": {},
                    "tag": "direct"
                }
            ],
            "routing": {
                "rules": [
                    {
                        "type": "field",
                        "ip": ["geoip:private"],
                        "outboundTag": "direct"
                    },
                    {
                        "type": "field",
                        "outboundTag": "proxy"
                    }
                ]
            }
        }
        
        # 添加TLS配置
        if self.params.get("security") == "tls" or self.params.get("security") == "reality":
            config["outbounds"][0]["streamSettings"]["tlsSettings"] = {
                "serverName": self.params.get("sni", ""),
                "fingerprint": self.params.get("fp", "chrome")
            }
        
        # 添加Reality配置
        if self.params.get("security") == "reality":
            config["outbounds"][0]["streamSettings"]["realitySettings"] = {
                "show": False,
                "publicKey": self.params.get("pbk", ""),
                "shortId": self.params.get("sid", ""),
                "spiderX": self.params.get("spx", "")
            }
        
        # 添加传输配置
        network = self.params.get("type", "tcp")
        if network == "ws":
            config["outbounds"][0]["streamSettings"]["wsSettings"] = {
                "path": self.params.get("path", "/"),
                "headers": {
                    "Host": self.params.get("host", self.address)
                }
            }
        elif network == "grpc":
            config["outbounds"][0]["streamSettings"]["grpcSettings"] = {
                "serviceName": self.params.get("serviceName", "")
            }
        
        self.local_port = local_port
        return config
    
    def to_sing_box_config(self, local_port=1080, local_address="127.0.0.1"):
        """转换为sing-box配置
        
        Args:
            local_port: 本地代理端口
            local_address: 本地代理地址
            
        Returns:
            dict: sing-box配置字典
        """
        config = {
            "log": {
                "level": "info",
                "timestamp": True
            },
            "inbounds": [
                {
                    "type": "socks",
                    "tag": "socks-in",
                    "listen": local_address,
                    "listen_port": local_port,
                    "users": [],
                    "udp": True
                },
                {
                    "type": "http",
                    "tag": "http-in",
                    "listen": local_address,
                    "listen_port": local_port + 1,
                    "users": []
                }
            ],
            "outbounds": [
                {
                    "type": "vless",
                    "tag": "vless-out",
                    "server": self.address,
                    "server_port": self.port,
                    "uuid": self.user_id,
                    "flow": self.params.get("flow", ""),
                    "network": self.params.get("type", "tcp"),
                    "packet_encoding": "",
                    "tls": {}
                },
                {
                    "type": "direct",
                    "tag": "direct"
                },
                {
                    "type": "block",
                    "tag": "block"
                }
            ],
            "route": {
                "rules": [
                    {
                        "geoip": ["private"],
                        "outbound": "direct"
                    },
                    {
                        "geosite": ["category-ads-all"],
                        "outbound": "block"
                    }
                ],
                "final": "vless-out"
            }
        }
        
        # 添加TLS配置
        if self.params.get("security") == "tls" or self.params.get("security") == "reality":
            config["outbounds"][0]["tls"] = {
                "enabled": True,
                "server_name": self.params.get("sni", ""),
                "utls": {
                    "enabled": True,
                    "fingerprint": self.params.get("fp", "chrome")
                }
            }
        
        # 添加Reality配置
        if self.params.get("security") == "reality":
            config["outbounds"][0]["tls"]["reality"] = {
                "enabled": True,
                "public_key": self.params.get("pbk", ""),
                "short_id": self.params.get("sid", "")
            }
            if "spx" in self.params:
                config["outbounds"][0]["tls"]["reality"]["spider_x"] = self.params.get("spx", "")
        
        # 添加传输配置
        network = self.params.get("type", "tcp")
        if network == "ws":
            config["outbounds"][0]["transport"] = {
                "type": "ws",
                "path": self.params.get("path", "/"),
                "headers": {
                    "Host": self.params.get("host", self.address)
                }
            }
        elif network == "grpc":
            config["outbounds"][0]["transport"] = {
                "type": "grpc",
                "service_name": self.params.get("serviceName", "")
            }
        
        self.local_port = local_port
        return config
    
    def get_proxy_url(self, protocol="socks5"):
        """获取代理URL
        
        Args:
            protocol: 代理协议，socks5或http
            
        Returns:
            str: 代理URL
        """
        if not self.local_port:
            return None
        
        if protocol == "socks5":
            return f"socks5://127.0.0.1:{self.local_port}"
        elif protocol == "http":
            return f"http://127.0.0.1:{self.local_port + 1}"
        else:
            return None
    
    def __str__(self):
        """字符串表示"""
        return f"VLESS://{self.user_id}@{self.address}:{self.port} [{self.tag}]"

class ProxyManager:
    """代理管理类"""
    
    def __init__(self, config_file=None, config=None):
        """初始化代理管理器
        
        Args:
            config_file: 配置文件路径
            config: 配置字典，优先级高于配置文件
        """
        # 默认配置
        self.config = {
            "proxy": {
                "enabled": True,
                "type": "vless",  # 代理类型：vless, http, socks5
                "vless_uris": [
                    # VLESS URI格式的代理配置
                ],
                "http_proxies": [
                    # 格式: "http://user:pass@host:port"
                ],
                "socks5_proxies": [
                    # 格式: "socks5://user:pass@host:port"
                ],
                "sing_box_bin": "sing-box",  # sing-box可执行文件路径
                "use_sing_box": True,  # 是否使用本地sing-box客户端
                "v2ray_bin": "v2ray",  # v2ray可执行文件路径
                "use_local_v2ray": False,  # 是否使用本地v2ray客户端
                "local_port_start": 10800,  # 本地代理端口起始值
                "rotation_interval": 10,  # 代理轮换间隔（请求次数）
                "retry_times": 3,  # 代理失败重试次数
                "timeout": 10,  # 请求超时时间（秒）
                "test_url": "https://api.ipify.org?format=json",  # 代理测试URL
                "blacklist_time": 300  # 代理黑名单时间（秒）
            },
            "user_agent": {
                "enabled": True,
                "rotation": "random",  # random, pool
                "custom_agents": [
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
                ]
            },
            "cookie": {
                "enabled": True,
                "save_path": "cookies.txt",  # Cookie保存路径
                "domains": ["gate.io", "www.gate.io"],  # 需要管理Cookie的域名
                "expire_days": 7  # Cookie过期天数
            },
            "behavior": {
                "enabled": True,
                "random_delay": {
                    "min": 1,  # 最小延迟（秒）
                    "max": 3   # 最大延迟（秒）
                },
                "visit_patterns": {
                    "enabled": True,
                    "entry_pages": [
                        "https://www.gate.io/",
                        "https://www.gate.io/trade/BTC_USDT"
                    ],
                    "random_pages": [
                        "https://www.gate.io/trade/ETH_USDT",
                        "https://www.gate.io/marketlist"
                    ],
                    "probability": 0.3  # 随机访问概率
                }
            }
        }
        
        # 如果提供了配置字典，则直接使用
        if config:
            self.update_config(self.config, config)
            logger.info("已加载配置字典")
        # 如果提供了配置文件，则加载配置
        elif config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    user_config = json.load(f)
                    self.update_config(self.config, user_config)
                logger.info(f"已加载配置文件: {config_file}")
            except Exception as e:
                logger.error(f"加载配置文件失败: {e}")
        
        # 初始化状态
        self.current_proxy = None
        self.proxy_index = 0
        self.request_count = 0
        self.proxy_blacklist = {}  # 代理黑名单
        self.domain_cookies = defaultdict(dict)  # 按域名存储Cookie
        self.session = requests.Session()  # 会话对象
        self.lock = threading.Lock()  # 线程锁
        self.vless_proxies = []  # VLESS代理列表
        self.running_proxies = {}  # 运行中的代理进程
        
        # 初始化User-Agent生成器
        if HAS_FAKE_UA:
            try:
                self.ua = UserAgent()
                logger.info("User-Agent生成器初始化成功")
            except Exception as e:
                logger.warning(f"User-Agent生成器初始化失败: {e}，将使用自定义User-Agent")
                self.ua = None
        else:
            self.ua = None
            logger.warning("未安装fake-useragent库，将使用自定义User-Agent")
        
        # 加载Cookie
        self.load_cookies()
        
        # 初始化代理列表
        self.available_proxies = []
        self.init_proxies()
    
    def update_config(self, target, source):
        """递归更新配置字典"""
        for key, value in source.items():
            if key in target and isinstance(target[key], dict) and isinstance(value, dict):
                self.update_config(target[key], value)
            else:
                target[key] = value
    
    def init_proxies(self):
        """初始化代理列表"""
        if not self.config["proxy"]["enabled"]:
            logger.info("代理功能未启用")
            return
        
        proxy_type = self.config["proxy"]["type"]
        
        if proxy_type == "vless":
            self.init_vless_proxies()
        elif proxy_type == "http":
            self.available_proxies = self.config["proxy"]["http_proxies"]
            logger.info(f"已加载 {len(self.available_proxies)} 个HTTP代理")
        elif proxy_type == "socks5":
            self.available_proxies = self.config["proxy"]["socks5_proxies"]
            logger.info(f"已加载 {len(self.available_proxies)} 个SOCKS5代理")
        else:
            logger.error(f"不支持的代理类型: {proxy_type}")
        
        # 测试代理可用性
        self.test_proxies()
    
    def init_vless_proxies(self):
        """初始化VLESS代理"""
        vless_uris = self.config["proxy"]["vless_uris"]
        
        if not vless_uris:
            logger.warning("未配置VLESS URI")
            return
        
        # 解析VLESS URI
        for uri in vless_uris:
            proxy = VLESSProxy(uri)
            if proxy.user_id and proxy.address:
                self.vless_proxies.append(proxy)
        
        logger.info(f"已加载 {len(self.vless_proxies)} 个VLESS代理")
        
        # 如果使用本地sing-box客户端，则启动代理
        if self.config["proxy"]["use_sing_box"]:
            self.start_local_proxies_sing_box()
        # 如果使用本地v2ray客户端，则启动代理
        elif self.config["proxy"]["use_local_v2ray"]:
            self.start_local_proxies_v2ray()
    
    def start_local_proxies_sing_box(self):
        """启动本地sing-box代理"""
        if not self.vless_proxies:
            logger.warning("没有可用的VLESS代理")
            return
        
        sing_box_bin = self.config["proxy"]["sing_box_bin"]
        local_port_start = self.config["proxy"]["local_port_start"]
        
        # 检查sing-box是否可用
        try:
            subprocess.run([sing_box_bin, "version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        except Exception as e:
            logger.error(f"sing-box不可用: {e}")
            return
        
        # 启动代理
        for i, proxy in enumerate(self.vless_proxies):
            local_port = local_port_start + i * 2
            config = proxy.to_sing_box_config(local_port)
            
            # 保存配置文件
            config_file = f"sing_box_config_{i}.json"
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            # 启动sing-box
            try:
                process = subprocess.Popen(
                    [sing_box_bin, "run", "-c", config_file],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                
                # 等待启动
                time.sleep(2)
                
                # 检查进程是否存活
                if process.poll() is None:
                    self.running_proxies[proxy] = process
                    proxy_url = proxy.get_proxy_url("socks5")
                    self.available_proxies.append(proxy_url)
                    logger.info(f"启动本地代理成功: {proxy_url}")
                else:
                    stdout, stderr = process.communicate()
                    logger.error(f"启动本地代理失败: {stderr.decode('utf-8', errors='ignore')}")
            
            except Exception as e:
                logger.error(f"启动本地代理异常: {e}")
    
    def start_local_proxies_v2ray(self):
        """启动本地v2ray代理"""
        if not self.vless_proxies:
            logger.warning("没有可用的VLESS代理")
            return
        
        v2ray_bin = self.config["proxy"]["v2ray_bin"]
        local_port_start = self.config["proxy"]["local_port_start"]
        
        # 检查v2ray是否可用
        try:
            subprocess.run([v2ray_bin, "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        except Exception as e:
            logger.error(f"v2ray不可用: {e}")
            return
        
        # 启动代理
        for i, proxy in enumerate(self.vless_proxies):
            local_port = local_port_start + i * 2
            config = proxy.to_v2ray_config(local_port)
            
            # 保存配置文件
            config_file = f"v2ray_config_{i}.json"
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            # 启动v2ray
            try:
                process = subprocess.Popen(
                    [v2ray_bin, "-c", config_file],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE
                )
                
                # 等待启动
                time.sleep(2)
                
                # 检查进程是否存活
                if process.poll() is None:
                    self.running_proxies[proxy] = process
                    proxy_url = proxy.get_proxy_url("socks5")
                    self.available_proxies.append(proxy_url)
                    logger.info(f"启动本地代理成功: {proxy_url}")
                else:
                    stdout, stderr = process.communicate()
                    logger.error(f"启动本地代理失败: {stderr.decode('utf-8', errors='ignore')}")
            
            except Exception as e:
                logger.error(f"启动本地代理异常: {e}")
    
    def stop_local_proxies(self):
        """停止本地代理"""
        for proxy, process in self.running_proxies.items():
            try:
                process.terminate()
                process.wait(timeout=5)
                logger.info(f"停止本地代理: {proxy}")
            except Exception as e:
                logger.error(f"停止本地代理失败: {e}")
                try:
                    process.kill()
                except:
                    pass
        
        self.running_proxies = {}
    
    def test_proxies(self):
        """测试代理可用性"""
        working_proxies = []
        
        for proxy in self.available_proxies:
            if self.test_proxy(proxy):
                working_proxies.append(proxy)
        
        self.available_proxies = working_proxies
        logger.info(f"代理测试完成，{len(working_proxies)}/{len(self.available_proxies)} 个代理可用")
    
    def test_proxy(self, proxy):
        """测试单个代理的可用性"""
        try:
            # 设置代理
            if proxy.startswith("http"):
                proxies = {"http": proxy, "https": proxy}
            elif proxy.startswith("socks5"):
                proxies = {"http": proxy, "https": proxy}
            else:
                logger.error(f"不支持的代理格式: {proxy}")
                return False
            
            # 测试连接
            response = requests.get(
                self.config["proxy"]["test_url"],
                proxies=proxies,
                timeout=self.config["proxy"]["timeout"]
            )
            
            if response.status_code == 200:
                logger.info(f"代理测试成功: {proxy}")
                return True
            else:
                logger.warning(f"代理测试失败，状态码: {response.status_code}, 代理: {proxy}")
                return False
        
        except Exception as e:
            logger.warning(f"代理测试异常: {e}, 代理: {proxy}")
            return False
    
    def get_proxy(self):
        """获取代理"""
        with self.lock:
            # 如果没有可用代理，返回None
            if not self.available_proxies:
                return None
            
            # 如果请求次数达到轮换间隔，切换代理
            if self.request_count >= self.config["proxy"]["rotation_interval"]:
                self.proxy_index = (self.proxy_index + 1) % len(self.available_proxies)
                self.request_count = 0
            
            # 获取当前代理
            proxy = self.available_proxies[self.proxy_index]
            
            # 检查代理是否在黑名单中
            if proxy in self.proxy_blacklist:
                blacklist_time = self.proxy_blacklist[proxy]
                if time.time() - blacklist_time < self.config["proxy"]["blacklist_time"]:
                    # 代理仍在黑名单中，尝试下一个代理
                    self.proxy_index = (self.proxy_index + 1) % len(self.available_proxies)
                    proxy = self.available_proxies[self.proxy_index]
                else:
                    # 代理已从黑名单中移除
                    del self.proxy_blacklist[proxy]
            
            # 更新请求计数
            self.request_count += 1
            
            # 更新当前代理
            self.current_proxy = proxy
            
            return proxy
    
    def blacklist_proxy(self, proxy):
        """将代理加入黑名单"""
        with self.lock:
            self.proxy_blacklist[proxy] = time.time()
            logger.warning(f"代理已加入黑名单: {proxy}")
    
    def get_user_agent(self):
        """获取User-Agent"""
        if not self.config["user_agent"]["enabled"]:
            return None
        
        if self.config["user_agent"]["rotation"] == "random":
            if self.ua:
                return self.ua.random
            else:
                return random.choice(self.config["user_agent"]["custom_agents"])
        else:
            return random.choice(self.config["user_agent"]["custom_agents"])
    
    def load_cookies(self):
        """加载Cookie"""
        if not self.config["cookie"]["enabled"]:
            return
        
        cookie_path = self.config["cookie"]["save_path"]
        
        if os.path.exists(cookie_path):
            try:
                cookie_jar = LWPCookieJar(cookie_path)
                cookie_jar.load(ignore_discard=True, ignore_expires=True)
                
                # 将Cookie加载到会话
                self.session.cookies = cookie_jar
                
                logger.info(f"已加载Cookie: {cookie_path}")
            except Exception as e:
                logger.error(f"加载Cookie失败: {e}")
    
    def save_cookies(self):
        """保存Cookie"""
        if not self.config["cookie"]["enabled"]:
            return
        
        cookie_path = self.config["cookie"]["save_path"]
        
        try:
            # 创建Cookie容器
            cookie_jar = LWPCookieJar(cookie_path)
            
            # 将会话Cookie复制到容器
            for cookie in self.session.cookies:
                cookie_jar.set_cookie(cookie)
            
            # 保存Cookie
            cookie_jar.save(ignore_discard=True, ignore_expires=True)
            
            logger.info(f"已保存Cookie: {cookie_path}")
        except Exception as e:
            logger.error(f"保存Cookie失败: {e}")
    
    def request(self, method, url, **kwargs):
        """发送HTTP请求
        
        Args:
            method: 请求方法，如GET、POST
            url: 请求URL
            **kwargs: 其他请求参数
            
        Returns:
            requests.Response: 响应对象
        """
        # 如果代理功能未启用，直接发送请求
        if not self.config["proxy"]["enabled"]:
            return self.session.request(method, url, **kwargs)
        
        # 获取代理
        proxy = self.get_proxy()
        
        if not proxy:
            logger.warning("没有可用代理，将直接发送请求")
            return self.session.request(method, url, **kwargs)
        
        # 设置代理
        if proxy.startswith("http"):
            proxies = {"http": proxy, "https": proxy}
        elif proxy.startswith("socks5"):
            proxies = {"http": proxy, "https": proxy}
        else:
            logger.error(f"不支持的代理格式: {proxy}")
            return self.session.request(method, url, **kwargs)
        
        # 设置User-Agent
        headers = kwargs.get("headers", {})
        user_agent = self.get_user_agent()
        
        if user_agent:
            headers["User-Agent"] = user_agent
            kwargs["headers"] = headers
        
        # 设置超时
        kwargs.setdefault("timeout", self.config["proxy"]["timeout"])
        
        # 添加随机延迟
        if self.config["behavior"]["enabled"] and self.config["behavior"]["random_delay"]["enabled"]:
            min_delay = self.config["behavior"]["random_delay"]["min"]
            max_delay = self.config["behavior"]["random_delay"]["max"]
            delay = random.uniform(min_delay, max_delay)
            time.sleep(delay)
        
        # 发送请求
        retry_times = self.config["proxy"]["retry_times"]
        
        for i in range(retry_times):
            try:
                response = self.session.request(method, url, proxies=proxies, **kwargs)
                
                # 保存Cookie
                self.save_cookies()
                
                return response
            
            except (RequestException, ProxyError, Timeout) as e:
                logger.warning(f"请求失败 ({i+1}/{retry_times}): {e}, 代理: {proxy}")
                
                # 最后一次重试失败，将代理加入黑名单
                if i == retry_times - 1:
                    self.blacklist_proxy(proxy)
                    
                    # 尝试使用下一个代理
                    proxy = self.get_proxy()
                    
                    if not proxy:
                        logger.error("没有可用代理，请求失败")
                        raise
                    
                    # 更新代理设置
                    if proxy.startswith("http"):
                        proxies = {"http": proxy, "https": proxy}
                    elif proxy.startswith("socks5"):
                        proxies = {"http": proxy, "https": proxy}
        
        # 所有重试都失败
        raise RequestException(f"请求失败，已重试 {retry_times} 次")
    
    def get(self, url, **kwargs):
        """发送GET请求"""
        return self.request("GET", url, **kwargs)
    
    def post(self, url, **kwargs):
        """发送POST请求"""
        return self.request("POST", url, **kwargs)
    
    def __del__(self):
        """析构函数"""
        self.stop_local_proxies()

# 兼容旧版本
VLESSProxyManager = ProxyManager
