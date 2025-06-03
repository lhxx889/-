#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
VLESS和Telegram一键设置工具
功能：
1. 自动解析VLESS URI
2. 自动安装v2ray客户端
3. 自动生成v2ray配置
4. 自动启动v2ray服务
5. 自动验证代理连接
6. 自动配置Telegram Bot
"""

import os
import sys
import json
import time
import subprocess
import argparse
import requests
import re
import base64
import urllib.parse
import getpass
from urllib.parse import urlparse, parse_qs

# 颜色定义
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[0;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

def print_info(message):
    """打印信息"""
    print(f"{BLUE}[INFO]{NC} {message}")

def print_success(message):
    """打印成功信息"""
    print(f"{GREEN}[SUCCESS]{NC} {message}")

def print_warning(message):
    """打印警告信息"""
    print(f"{YELLOW}[WARNING]{NC} {message}")

def print_error(message):
    """打印错误信息"""
    print(f"{RED}[ERROR]{NC} {message}")

def run_command(command, shell=False):
    """运行命令并返回结果"""
    try:
        if shell:
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        stdout, stderr = process.communicate()
        return {
            "success": process.returncode == 0,
            "stdout": stdout.decode('utf-8', errors='ignore'),
            "stderr": stderr.decode('utf-8', errors='ignore'),
            "returncode": process.returncode
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": str(e),
            "returncode": -1
        }

def check_root():
    """检查是否为root用户"""
    return os.geteuid() == 0

def check_v2ray():
    """检查v2ray是否已安装"""
    result = run_command(["which", "v2ray"])
    return result["success"]

def install_v2ray():
    """安装v2ray"""
    print_info("正在安装v2ray...")
    
    # 下载安装脚本
    download_result = run_command("curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh -o install-v2ray.sh", shell=True)
    
    if not download_result["success"]:
        print_error(f"下载v2ray安装脚本失败: {download_result['stderr']}")
        return False
    
    # 设置执行权限
    chmod_result = run_command("chmod +x install-v2ray.sh", shell=True)
    
    if not chmod_result["success"]:
        print_error(f"设置v2ray安装脚本执行权限失败: {chmod_result['stderr']}")
        return False
    
    # 执行安装脚本
    install_result = run_command("bash install-v2ray.sh", shell=True)
    
    if not install_result["success"]:
        print_error(f"安装v2ray失败: {install_result['stderr']}")
        return False
    
    print_success("v2ray安装完成")
    return True

class VLESSSetup:
    """VLESS设置类"""
    
    def __init__(self):
        """初始化"""
        self.protocol = "vless"
        self.user_id = ""
        self.address = ""
        self.port = 443
        self.params = {}
        self.tag = ""
        self.local_port = 10808
        self.config_file = "/usr/local/etc/v2ray/config.json"
        self.service_name = "v2ray"
    
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
                print_error("不是有效的VLESS URI")
                return False
            
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
            
            print_success(f"成功解析VLESS URI: {self.address}:{self.port}, 标签: {self.tag}")
            return True
        
        except Exception as e:
            print_error(f"解析VLESS URI失败: {e}")
            return False
    
    def generate_config(self):
        """生成v2ray配置"""
        config = {
            "log": {
                "loglevel": "warning"
            },
            "inbounds": [
                {
                    "port": self.local_port,
                    "listen": "127.0.0.1",
                    "protocol": "socks",
                    "settings": {
                        "udp": True
                    }
                },
                {
                    "port": self.local_port + 1,
                    "listen": "127.0.0.1",
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
        
        return config
    
    def save_config(self, config):
        """保存v2ray配置"""
        try:
            # 确保目录存在
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            
            # 保存配置
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            print_success(f"配置已保存到: {self.config_file}")
            return True
        
        except Exception as e:
            print_error(f"保存配置失败: {e}")
            return False
    
    def restart_service(self):
        """重启v2ray服务"""
        print_info("重启v2ray服务...")
        
        # 停止服务
        stop_result = run_command(f"systemctl stop {self.service_name}", shell=True)
        
        if not stop_result["success"]:
            print_warning(f"停止服务失败: {stop_result['stderr']}")
        
        # 启动服务
        start_result = run_command(f"systemctl start {self.service_name}", shell=True)
        
        if not start_result["success"]:
            print_error(f"启动服务失败: {start_result['stderr']}")
            return False
        
        # 检查服务状态
        status_result = run_command(f"systemctl status {self.service_name}", shell=True)
        
        if "Active: active (running)" in status_result["stdout"]:
            print_success("v2ray服务已启动")
            return True
        else:
            print_error("v2ray服务启动失败")
            return False
    
    def test_proxy(self):
        """测试代理连接"""
        print_info("测试代理连接...")
        
        # 等待服务启动
        time.sleep(2)
        
        # 设置代理
        proxies = {
            "http": f"socks5://127.0.0.1:{self.local_port}",
            "https": f"socks5://127.0.0.1:{self.local_port}"
        }
        
        try:
            # 测试连接
            response = requests.get("https://api.ipify.org?format=json", proxies=proxies, timeout=10)
            
            if response.status_code == 200:
                ip = response.json().get("ip", "未知")
                print_success(f"代理连接成功，当前IP: {ip}")
                return True
            else:
                print_error(f"代理连接失败，状态码: {response.status_code}")
                return False
        
        except Exception as e:
            print_error(f"代理连接测试失败: {e}")
            return False
    
    def save_to_config_vless(self):
        """保存到config_vless.json"""
        config_file = "config_vless.json"
        
        try:
            # 读取现有配置
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    config = json.load(f)
            else:
                config = {
                    "proxy": {
                        "enabled": True,
                        "type": "vless",
                        "vless_uris": [],
                        "use_local_v2ray": True,
                        "v2ray_bin": "v2ray",
                        "local_port_start": 10800,
                        "rotation_interval": 10,
                        "retry_times": 3,
                        "timeout": 10,
                        "test_url": "https://api.ipify.org?format=json",
                        "blacklist_time": 300
                    },
                    "user_agent": {
                        "enabled": True,
                        "rotation": "random",
                        "custom_agents": [
                            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
                            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15",
                            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
                        ]
                    },
                    "cookie": {
                        "enabled": True,
                        "save_path": "cookies.txt",
                        "domains": ["gate.io", "www.gate.io"],
                        "expire_days": 7
                    },
                    "behavior": {
                        "enabled": True,
                        "random_delay": {
                            "min": 1,
                            "max": 3
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
                            "probability": 0.3
                        }
                    }
                }
            
            # 构建VLESS URI
            vless_uri = f"vless://{self.user_id}@{self.address}:{self.port}/?"
            
            # 添加参数
            params = []
            for key, value in self.params.items():
                params.append(f"{key}={value}")
            
            vless_uri += "&".join(params)
            
            # 添加标签
            if self.tag:
                vless_uri += f"#{urllib.parse.quote(self.tag)}"
            
            # 更新配置
            if vless_uri not in config["proxy"]["vless_uris"]:
                config["proxy"]["vless_uris"].insert(0, vless_uri)
            
            # 保存配置
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            print_success(f"VLESS URI已保存到: {config_file}")
            return True
        
        except Exception as e:
            print_error(f"保存到config_vless.json失败: {e}")
            return False

class TelegramSetup:
    """Telegram设置类"""
    
    def __init__(self):
        """初始化"""
        self.bot_token = ""
        self.chat_id = ""
        self.config_file = "telegram_config.json"
    
    def input_credentials(self):
        """输入Telegram凭据"""
        print_info("请输入Telegram Bot凭据")
        print_info("您可以通过 @BotFather 创建Bot并获取Token")
        print_info("您可以通过 @userinfobot 获取您的Chat ID")
        
        self.bot_token = input("Bot Token: ").strip()
        self.chat_id = input("Chat ID: ").strip()
        
        return bool(self.bot_token and self.chat_id)
    
    def verify_credentials(self):
        """验证Telegram Bot凭据"""
        print_info("正在验证Telegram Bot凭据...")
        
        if not self.bot_token or not self.chat_id:
            print_error("Bot Token和Chat ID不能为空")
            return False
        
        try:
            # 构建API URL
            url = f"https://api.telegram.org/bot{self.bot_token}/getMe"
            
            # 发送请求
            response = requests.get(url, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get("ok"):
                    bot_name = data.get("result", {}).get("username", "未知")
                    print_success(f"Bot Token验证成功，Bot名称: @{bot_name}")
                    
                    # 验证Chat ID
                    return self.verify_chat_id()
                else:
                    print_error(f"Bot Token验证失败: {data.get('description', '未知错误')}")
                    return False
            else:
                print_error(f"Bot Token验证失败，状态码: {response.status_code}")
                return False
        
        except Exception as e:
            print_error(f"验证失败: {e}")
            return False
    
    def verify_chat_id(self):
        """验证Chat ID"""
        print_info("正在验证Chat ID...")
        
        try:
            # 构建API URL
            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            
            # 构建参数
            params = {
                "chat_id": self.chat_id,
                "text": "✅ Gate.io监控系统: Telegram Bot设置验证成功！\n\n此消息表明您的Bot Token和Chat ID配置正确。",
                "parse_mode": "HTML"
            }
            
            # 发送请求
            response = requests.post(url, json=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                
                if data.get("ok"):
                    print_success("Chat ID验证成功，已发送测试消息")
                    return True
                else:
                    print_error(f"Chat ID验证失败: {data.get('description', '未知错误')}")
                    return False
            else:
                print_error(f"Chat ID验证失败，状态码: {response.status_code}")
                return False
        
        except Exception as e:
            print_error(f"验证失败: {e}")
            return False
    
    def save_config(self):
        """保存Telegram配置"""
        try:
            config = {
                "accounts": [
                    {
                        "bot_token": self.bot_token,
                        "chat_id": self.chat_id,
                        "enabled": True
                    }
                ],
                "rotation_strategy": "round_robin",
                "message_format": "html",
                "summary_interval": 86400,
                "interactive_commands": True
            }
            
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            print_success(f"Telegram配置已保存到: {self.config_file}")
            return True
        
        except Exception as e:
            print_error(f"保存配置失败: {e}")
            return False

def setup_vless():
    """设置VLESS代理"""
    print_info("开始设置VLESS代理...")
    
    # 获取VLESS URI
    uri = input("请输入VLESS URI: ")
    
    if not uri:
        print_error("VLESS URI不能为空")
        return False
    
    # 检查v2ray是否已安装
    if not check_v2ray():
        print_warning("v2ray未安装")
        
        # 安装v2ray
        if not install_v2ray():
            print_error("v2ray安装失败，请手动安装")
            return False
    
    # 创建VLESS设置实例
    vless_setup = VLESSSetup()
    
    # 解析URI
    if not vless_setup.parse_uri(uri):
        return False
    
    # 生成配置
    config = vless_setup.generate_config()
    
    # 保存配置
    if not vless_setup.save_config(config):
        return False
    
    # 重启服务
    if not vless_setup.restart_service():
        return False
    
    # 测试代理
    if not vless_setup.test_proxy():
        return False
    
    # 保存到config_vless.json
    vless_setup.save_to_config_vless()
    
    print_success("VLESS代理设置完成")
    return True

def setup_telegram():
    """设置Telegram Bot"""
    print_info("开始设置Telegram Bot...")
    
    # 创建Telegram设置实例
    telegram_setup = TelegramSetup()
    
    # 输入凭据
    if not telegram_setup.input_credentials():
        print_error("凭据不完整，无法继续")
        return False
    
    # 验证凭据
    if not telegram_setup.verify_credentials():
        print_error("凭据验证失败，无法继续")
        return False
    
    # 保存配置
    if not telegram_setup.save_config():
        print_error("保存配置失败，无法继续")
        return False
    
    print_success("Telegram Bot设置完成")
    return True

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="VLESS和Telegram一键设置工具")
    parser.add_argument("--vless", help="VLESS URI")
    parser.add_argument("--bot_token", help="Telegram Bot Token")
    parser.add_argument("--chat_id", help="Telegram Chat ID")
    args = parser.parse_args()
    
    print("====================================================")
    print("      VLESS和Telegram一键设置工具                   ")
    print("====================================================")
    
    # 检查是否为root用户
    if not check_root():
        print_warning("当前非root用户，部分功能可能受限")
        print_warning("建议使用 sudo python3 setup_vless_telegram.py 运行此脚本")
    
    # 设置VLESS代理
    if args.vless:
        # 使用命令行参数
        uri = args.vless
        
        # 检查v2ray是否已安装
        if not check_v2ray():
            print_warning("v2ray未安装")
            
            # 安装v2ray
            if not install_v2ray():
                print_error("v2ray安装失败，请手动安装")
                return
        
        # 创建VLESS设置实例
        vless_setup = VLESSSetup()
        
        # 解析URI
        if not vless_setup.parse_uri(uri):
            return
        
        # 生成配置
        config = vless_setup.generate_config()
        
        # 保存配置
        if not vless_setup.save_config(config):
            return
        
        # 重启服务
        if not vless_setup.restart_service():
            return
        
        # 测试代理
        if not vless_setup.test_proxy():
            return
        
        # 保存到config_vless.json
        vless_setup.save_to_config_vless()
        
        print_success("VLESS代理设置完成")
    else:
        # 交互式设置
        setup_vless()
    
    # 设置Telegram Bot
    if args.bot_token and args.chat_id:
        # 使用命令行参数
        telegram_setup = TelegramSetup()
        telegram_setup.bot_token = args.bot_token
        telegram_setup.chat_id = args.chat_id
        
        # 验证凭据
        if not telegram_setup.verify_credentials():
            print_error("Telegram凭据验证失败，无法继续")
            return
        
        # 保存配置
        if not telegram_setup.save_config():
            print_error("保存Telegram配置失败，无法继续")
            return
        
        print_success("Telegram Bot设置完成")
    else:
        # 交互式设置
        setup_telegram()
    
    print("====================================================")
    print_success("VLESS和Telegram一键设置完成！")
    print("====================================================")

if __name__ == "__main__":
    main()
