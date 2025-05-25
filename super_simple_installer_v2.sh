#!/bin/bash
# 超级简易一键安装脚本 - 极简版 V2
# 包含所有功能：增强快捷键(db/jk/api/bd)、配置记忆、启动推送

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 定义安装目录
INSTALL_DIR="$HOME/crypto_monitor"

# 显示欢迎信息
clear
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}     Gate.io加密货币异动监控系统 - 极简安装脚本     ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "欢迎使用Gate.io加密货币异动监控系统！"
echo -e "这个脚本会自动为您完成所有安装和配置步骤。"
echo ""

# 安装必要工具
echo -e "${YELLOW}正在安装必要工具...${NC}"
sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-pip

# 创建安装目录
echo -e "${YELLOW}正在创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 创建必要的目录结构
mkdir -p src data

# 安装Python依赖
echo -e "${YELLOW}正在安装Python依赖...${NC}"
pip3 install requests

# 创建主程序
echo -e "${YELLOW}正在创建主程序...${NC}"
cat > src/main.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import time
import json
import logging
import requests
import threading
from datetime import datetime

# 配置
CHECK_INTERVAL = 50  # 检查间隔（秒）
PRICE_CHANGE_THRESHOLD = 45.0  # 价格波动阈值（百分比）
VOLUME_SURGE_THRESHOLD = 200.0  # 交易量猛增阈值（百分比）
API_URL = "https://api.gateio.ws/api/v4"
BACKUP_API_URLS = ["https://api.gateio.io/api/v4", "https://api.gate.io/api/v4"]
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
CONFIG_FILE = os.path.join(DATA_DIR, "user_config.json")

# 确保数据目录存在
os.makedirs(DATA_DIR, exist_ok=True)

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("crypto_monitor")

class TelegramBot:
    """Telegram机器人类"""
    
    def __init__(self, token):
        self.token = token
        self.api_url = f"https://api.telegram.org/bot{token}"
    
    def send_message(self, chat_id, text, parse_mode="HTML"):
        """发送消息"""
        try:
            url = f"{self.api_url}/sendMessage"
            data = {
                "chat_id": chat_id,
                "text": text,
                "parse_mode": parse_mode
            }
            response = requests.post(url, json=data, timeout=10)
            
            if response.status_code == 200:
                logger.info(f"已发送消息到Telegram")
                return True
            else:
                logger.error(f"发送消息到Telegram失败，状态码: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"发送消息到Telegram出错: {e}")
            return False

class CryptoMonitor:
    """加密货币监控器"""
    
    def __init__(self):
        self.running = False
        self.paused = False
        self.api_url = API_URL
        self.previous_data = {}
        self.current_data = {}
        self.user_config = self.load_user_config()
        
        # 设置快捷键
        self.shortcut_keys = {
            'jk': self.toggle_monitoring,  # 监控快捷键
            'db': self.setup_telegram,     # Telegram设置快捷键
            'api': self.api_settings,      # API设置快捷键
            'bd': self.change_threshold    # 涨幅警报阈值设置快捷键
        }
    
    def load_user_config(self):
        """加载用户配置"""
        default_config = {
            "telegram_bot_token": "",
            "telegram_chat_id": "",
            "price_change_threshold": PRICE_CHANGE_THRESHOLD,
            "volume_surge_threshold": VOLUME_SURGE_THRESHOLD,
            "check_interval": CHECK_INTERVAL,
            "api_url": API_URL,
            "last_update": ""
        }
        
        try:
            if os.path.exists(CONFIG_FILE):
                with open(CONFIG_FILE, 'r') as f:
                    config = json.load(f)
                    default_config.update(config)
                    logger.info("已加载用户配置")
                    
                    # 更新全局变量
                    global PRICE_CHANGE_THRESHOLD, VOLUME_SURGE_THRESHOLD, CHECK_INTERVAL, API_URL
                    PRICE_CHANGE_THRESHOLD = default_config["price_change_threshold"]
                    VOLUME_SURGE_THRESHOLD = default_config["volume_surge_threshold"]
                    CHECK_INTERVAL = default_config["check_interval"]
                    API_URL = default_config["api_url"]
                    self.api_url = API_URL
            else:
                logger.info("未找到用户配置，使用默认配置")
        except Exception as e:
            logger.error(f"加载用户配置失败: {e}")
        
        return default_config
    
    def save_user_config(self):
        """保存用户配置"""
        try:
            # 更新配置
            self.user_config["price_change_threshold"] = PRICE_CHANGE_THRESHOLD
            self.user_config["volume_surge_threshold"] = VOLUME_SURGE_THRESHOLD
            self.user_config["check_interval"] = CHECK_INTERVAL
            self.user_config["api_url"] = self.api_url
            self.user_config["last_update"] = datetime.now().isoformat()
            
            with open(CONFIG_FILE, 'w') as f:
                json.dump(self.user_config, f)
            logger.info("已保存用户配置")
        except Exception as e:
            logger.error(f"保存用户配置失败: {e}")
    
    def setup_bot(self):
        """设置Telegram机器人"""
        # 检查是否已有配置
        if self.user_config["telegram_bot_token"] and self.user_config["telegram_chat_id"]:
            print(f"已有Telegram配置:")
            print(f"Bot Token: {self.user_config['telegram_bot_token'][:5]}...")
            print(f"Chat ID: {self.user_config['telegram_chat_id']}")
            
            # 询问是否需要重新设置
            print("是否需要重新设置Telegram? (y/n) [默认n]:")
            choice = input().strip().lower()
            
            if choice != 'y':
                # 测试现有配置
                bot = TelegramBot(self.user_config["telegram_bot_token"])
                success = bot.send_message(self.user_config["telegram_chat_id"], "Gate.io加密货币异动监控系统已启动，正在监控中...")
                
                if success:
                    logger.info("使用现有Telegram配置")
                    
                    # 确保菜单显示
                    print("\n")
                    print("配置完成，按Enter键显示交互菜单...")
                    input()  # 等待用户按Enter
                    
                    return True
                else:
                    logger.warning("现有Telegram配置无效，需要重新设置")
        
        # 需要重新设置
        print("请输入Telegram Bot Token:")
        token = input().strip()
        
        if not token:
            logger.error("Bot Token不能为空")
            return False
        
        self.user_config["telegram_bot_token"] = token
        
        print("请输入Telegram Chat ID (群组ID或频道用户名):")
        chat_id = input().strip()
        
        if not chat_id:
            logger.error("Chat ID不能为空")
            return False
        
        self.user_config["telegram_chat_id"] = chat_id
        
        # 发送测试消息
        bot = TelegramBot(token)
        success = bot.send_message(chat_id, "Gate.io加密货币异动监控系统已启动，正在监控中...")
        
        if not success:
            logger.error("发送测试消息失败，请检查Token和Chat ID是否正确")
            return False
        
        # 保存配置
        self.save_user_config()
        
        # 确保菜单显示
        print("\n")
        print("配置完成，按Enter键显示交互菜单...")
        input()  # 等待用户按Enter
        
        logger.info("Telegram机器人设置成功")
        return True
    
    def setup_telegram(self):
        """设置Telegram配置（快捷键db）"""
        print("\n" + "=" * 50)
        print("Telegram设置")
        print("=" * 50)
        
        # 显示当前配置
        if self.user_config["telegram_bot_token"] and self.user_config["telegram_chat_id"]:
            print(f"当前Bot Token: {self.user_config['telegram_bot_token'][:5]}...")
            print(f"当前Chat ID: {self.user_config['telegram_chat_id']}")
        else:
            print("当前未设置Telegram配置")
        
        # 询问是否更改
        print("\n是否更改Telegram配置? (y/n):")
        choice = input().strip().lower()
        
        if choice != 'y':
            print("保持当前配置")
            return
        
        # 更改配置
        print("\n请输入新的Telegram Bot Token:")
        token = input().strip()
        
        if token:
            self.user_config["telegram_bot_token"] = token
        
        print("请输入新的Telegram Chat ID:")
        chat_id = input().strip()
        
        if chat_id:
            self.user_config["telegram_chat_id"] = chat_id
        
        # 测试新配置
        if self.user_config["telegram_bot_token"] and self.user_config["telegram_chat_id"]:
            print("\n正在测试新配置...")
            bot = TelegramBot(self.user_config["telegram_bot_token"])
            success = bot.send_message(self.user_config["telegram_chat_id"], "Telegram配置测试消息")
            
            if success:
                print("测试成功，新配置有效")
                self.save_user_config()
            else:
                print("测试失败，请检查配置是否正确")
        else:
            print("配置不完整，无法测试")
    
    def api_settings(self):
        """API设置（快捷键api）"""
        print("\n" + "=" * 50)
        print("API设置")
        print("=" * 50)
        
        # 显示当前API
        print(f"当前API地址: {self.api_url}")
        
        # 显示可用API
        print("\n可用的API地址:")
        print(f"1. {API_URL} (主API)")
        for i, url in enumerate(BACKUP_API_URLS, 2):
            print(f"{i}. {url} (备用API)")
        
        # 询问是否更改
        print("\n请选择要使用的API地址编号，或输入0添加自定义API:")
        try:
            choice = int(input().strip())
            
            if choice == 1:
                self.api_url = API_URL
                print(f"已切换到主API: {self.api_url}")
            elif 2 <= choice <= len(BACKUP_API_URLS) + 1:
                self.api_url = BACKUP_API_URLS[choice - 2]
                print(f"已切换到备用API: {self.api_url}")
            elif choice == 0:
                print("\n请输入自定义API地址:")
                custom_url = input().strip()
                
                if custom_url:
                    # 测试自定义API
                    print("正在测试自定义API...")
                    try:
                        response = requests.get(f"{custom_url}/spot/tickers", timeout=5)
                        if response.status_code == 200:
                            self.api_url = custom_url
                            print(f"测试成功，已切换到自定义API: {self.api_url}")
                        else:
                            print(f"测试失败，状态码: {response.status_code}")
                    except Exception as e:
                        print(f"测试失败: {e}")
                else:
                    print("API地址不能为空")
            else:
                print("无效选项")
            
            # 保存配置
            self.save_user_config()
        except ValueError:
            print("请输入有效的数字")
    
    def change_threshold(self):
        """更改涨幅警报阈值（快捷键bd）"""
        global PRICE_CHANGE_THRESHOLD, VOLUME_SURGE_THRESHOLD, CHECK_INTERVAL
        
        print("\n" + "=" * 50)
        print("涨幅警报阈值设置")
        print("=" * 50)
        
        # 显示当前阈值
        print(f"当前价格波动阈值: {PRICE_CHANGE_THRESHOLD}%")
        print(f"当前交易量波动阈值: {VOLUME_SURGE_THRESHOLD}%")
        print(f"当前检查间隔: {CHECK_INTERVAL}秒")
        
        # 更改价格波动阈值
        print("\n请输入新的价格波动阈值(%)，或按Enter保持不变:")
        try:
            value = input().strip()
            if value:
                PRICE_CHANGE_THRESHOLD = float(value)
                print(f"价格波动阈值已更改为: {PRICE_CHANGE_THRESHOLD}%")
        except ValueError:
            print("无效输入，保持原值")
        
        # 更改交易量波动阈值
        print("\n请输入新的交易量波动阈值(%)，或按Enter保持不变:")
        try:
            value = input().strip()
            if value:
                VOLUME_SURGE_THRESHOLD = float(value)
                print(f"交易量波动阈值已更改为: {VOLUME_SURGE_THRESHOLD}%")
        except ValueError:
            print("无效输入，保持原值")
        
        # 更改检查间隔
        print("\n请输入新的检查间隔(秒)，或按Enter保持不变:")
        try:
            value = input().strip()
            if value:
                CHECK_INTERVAL = int(value)
                print(f"检查间隔已更改为: {CHECK_INTERVAL}秒")
        except ValueError:
            print("无效输入，保持原值")
        
        # 保存配置
        self.save_user_config()
    
    def fetch_all_tickers(self):
        """获取所有交易对的Ticker信息"""
        try:
            response = requests.get(f"{self.api_url}/spot/tickers", timeout=10)
            if response.status_code == 200:
                tickers = response.json()
                # 将列表转换为以currency_pair为键的字典
                self.current_data = {ticker["currency_pair"]: ticker for ticker in tickers}
                logger.info(f"已获取{len(self.current_data)}个交易对的Ticker信息")
                return True
            else:
                logger.error(f"获取Ticker信息失败，状态码: {response.status_code}")
                return False
        except Exception as e:
            logger.error(f"获取Ticker信息出错: {e}")
            
            # 尝试切换到备用API
            for backup_url in BACKUP_API_URLS:
                try:
                    logger.info(f"尝试切换到备用API: {backup_url}")
                    self.api_url = backup_url
                    response = requests.get(f"{self.api_url}/spot/tickers", timeout=10)
                    if response.status_code == 200:
                        tickers = response.json()
                        self.current_data = {ticker["currency_pair"]: ticker for ticker in tickers}
                        logger.info(f"已切换到备用API并获取{len(self.current_data)}个交易对的Ticker信息")
                        return True
                except Exception:
                    continue
            
            return False
    
    def detect_abnormal_movements(self):
        """检测异常波动"""
        if not self.previous_data:
            logger.info("没有上一次数据，无法检测异常波动")
            return []
        
        abnormal = []
        for pair, current in self.current_data.items():
            if pair not in self.previous_data:
                continue
            
            previous = self.previous_data[pair]
            
            # 计算价格变化百分比
            try:
                prev_price = float(previous.get("last", 0))
                curr_price = float(current.get("last", 0))
                if prev_price > 0:
                    price_change_pct = abs((curr_price - prev_price) / prev_price * 100)
                else:
                    price_change_pct = 0
                
                # 计算交易量变化百分比
                prev_volume = float(previous.get("base_volume", 0))
                curr_volume = float(current.get("base_volume", 0))
                if prev_volume > 0:
                    volume_change_pct = abs((curr_volume - prev_volume) / prev_volume * 100)
                else:
                    volume_change_pct = 0
                
                # 检测异常
                is_abnormal = False
                reasons = []
                
                if price_change_pct >= PRICE_CHANGE_THRESHOLD:
                    is_abnormal = True
                    direction = "上涨" if curr_price > prev_price else "下跌"
                    reasons.append(f"价格{direction}{price_change_pct:.2f}%")
                
                if volume_change_pct >= VOLUME_SURGE_THRESHOLD:
                    is_abnormal = True
                    direction = "增加" if curr_volume > prev_volume else "减少"
                    reasons.append(f"交易量{direction}{volume_change_pct:.2f}%")
                
                if is_abnormal:
                    abnormal.append({
                        "currency_pair": pair,
                        "current_price": curr_price,
                        "previous_price": prev_price,
                        "price_change_pct": price_change_pct,
                        "current_volume": curr_volume,
                        "previous_volume": prev_volume,
                        "volume_change_pct": volume_change_pct,
                        "reasons": reasons,
                        "timestamp": datetime.now().isoformat()
                    })
            except (ValueError, TypeError) as e:
                logger.error(f"处理交易对{pair}时出错: {e}")
        
        logger.info(f"检测到{len(abnormal)}个异常波动")
        return abnormal
    
    def process_abnormal_movements(self, abnormal_list):
        """处理异常波动"""
        if not abnormal_list:
            return
        
        for abnormal in abnormal_list:
            try:
                # 格式化异常消息
                currency_pair = abnormal.get("currency_pair", "")
                current_price = abnormal.get("current_price", 0)
                previous_price = abnormal.get("previous_price", 0)
                price_change_pct = abnormal.get("price_change_pct", 0)
                current_volume = abnormal.get("current_volume", 0)
                previous_volume = abnormal.get("previous_volume", 0)
                volume_change_pct = abnormal.get("volume_change_pct", 0)
                reasons = abnormal.get("reasons", [])
                timestamp = abnormal.get("timestamp", datetime.now().isoformat())
                
                # 格式化时间
                try:
                    dt = datetime.fromisoformat(timestamp)
                    formatted_time = dt.strftime("%Y-%m-%d %H:%M:%S")
                except:
                    formatted_time = timestamp
                
                # 价格变化方向
                price_direction = "上涨" if current_price > previous_price else "下跌"
                
                # 交易量变化方向
                volume_direction = "增加" if current_volume > previous_volume else "减少"
                
                # 格式化消息
                message = f"""
<b>⚠️ 加密货币异动警报</b>

<b>交易对:</b> {currency_pair}
<b>时间:</b> {formatted_time}

<b>价格变化:</b>
• 当前价格: {current_price}
• 之前价格: {previous_price}
• 变化幅度: {price_change_pct:.2f}% ({price_direction})

<b>交易量变化:</b>
• 当前交易量: {current_volume}
• 之前交易量: {previous_volume}
• 变化幅度: {volume_change_pct:.2f}% ({volume_direction})

<b>异动原因:</b>
• {', '.join(reasons)}

<i>系统将继续监控此交易对的变化情况。</i>
"""
                
                # 发送消息
                bot = TelegramBot(self.user_config["telegram_bot_token"])
                bot.send_message(self.user_config["telegram_chat_id"], message)
                
                logger.info(f"已发送{currency_pair}的异常波动警报")
            except Exception as e:
                logger.error(f"处理异常波动时出错: {e}")
    
    def send_status_report(self):
        """发送状态报告到Telegram"""
        try:
            if not self.user_config["telegram_bot_token"] or not self.user_config["telegram_chat_id"]:
                logger.error("Telegram未配置，无法发送状态报告")
                return False
            
            # 获取当前时间
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # 获取监控状态
            status = "运行中" if not self.paused else "已暂停"
            
            # 获取最新数据
            ticker_count = len(self.current_data)
            
            # 格式化消息
            message = f"""
<b>📊 Gate.io加密货币异动监控系统状态报告</b>

<b>系统状态:</b>
• 当前时间: {now}
• 监控状态: {status}
• API地址: {self.api_url}
• 监控币种数: {ticker_count}
• 价格波动阈值: {PRICE_CHANGE_THRESHOLD}%
• 交易量波动阈值: {VOLUME_SURGE_THRESHOLD}%
• 检查间隔: {CHECK_INTERVAL}秒

<b>快捷键:</b>
• jk: 开启/关闭监控
• db: 设置Telegram
• api: 设置API
• bd: 设置涨幅警报阈值

<i>系统正常运行中，如有异常波动将立即通知。</i>
"""
            
            # 发送消息
            bot = TelegramBot(self.user_config["telegram_bot_token"])
            success = bot.send_message(self.user_config["telegram_chat_id"], message)
            
            if success:
                logger.info("已发送状态报告到Telegram")
                return True
            else:
                logger.error("发送状态报告失败")
                return False
        except Exception as e:
            logger.error(f"发送状态报告时出错: {e}")
            return False
    
    def toggle_monitoring(self):
        """切换监控状态（快捷键jk）"""
        if self.paused:
            self.resume()
            print("已开启监控")
        else:
            self.pause()
            print("已关闭监控")
    
    def pause(self):
        """暂停监控"""
        self.paused = True
        logger.info("监控已暂停")
    
    def resume(self):
        """恢复监控"""
        self.paused = False
        logger.info("监控已恢复")
    
    def display_menu(self):
        """显示菜单"""
        print("\n" + "=" * 50)
        print("Gate.io加密货币异动监控系统 - 交互式菜单")
        print("=" * 50)
        print("1. 查看API地址")
        print("2. 切换API地址")
        print("3. 暂停/恢复监控")
        print("4. 发送状态报告到Telegram")
        print("5. 设置Telegram")
        print("6. 设置涨幅警报阈值")
        print("7. 退出菜单")
        print("0. 退出程序")
        print("=" * 50)
        print("快捷键: jk=开启/关闭监控, db=设置Telegram, api=设置API, bd=设置涨幅警报")
        print("=" * 50)
        print("请输入选项编号或快捷键:")
    
    def handle_menu_choice(self, choice):
        """处理菜单选择"""
        try:
            choice = choice.strip().lower()
            
            # 处理快捷键
            if choice in self.shortcut_keys:
                self.shortcut_keys[choice]()
                return True
            
            # 处理数字选项
            try:
                choice = int(choice)
                
                if choice == 1:
                    print(f"\n当前API地址: {self.api_url}")
                    print(f"备用API地址: {', '.join(BACKUP_API_URLS)}")
                elif choice == 2:
                    self.api_settings()
                elif choice == 3:
                    self.toggle_monitoring()
                elif choice == 4:
                    self.send_status_report()
                elif choice == 5:
                    self.setup_telegram()
                elif choice == 6:
                    self.change_threshold()
                elif choice == 7:
                    print("退出菜单，继续监控...")
                    return False
                elif choice == 0:
                    print("正在安全退出程序...")
                    self.running = False
                    return False
                else:
                    print("无效选项，请重新输入")
            except ValueError:
                print("无效输入，请输入数字或快捷键")
            
            return True
        except Exception as e:
            logger.error(f"处理菜单选择时出错: {e}")
            return True
    
    def start(self):
        """启动监控"""
        # 设置Telegram机器人
        if not self.setup_bot():
            logger.error("设置Telegram机器人失败，程序退出")
            return
        
        # 启动监控
        self.running = True
        self.paused = False
        
        # 发送启动状态报告
        self.send_status_report()
        
        # 主循环
        try:
            while self.running:
                # 显示菜单
                self.display_menu()
                
                # 等待用户输入
                choice = input().strip()
                
                # 处理菜单选择
                if not self.handle_menu_choice(choice):
                    continue
                
                # 如果没有暂停，执行监控
                if not self.paused:
                    print("\n正在检查异动情况...")
                    
                    # 获取所有交易对的Ticker信息
                    if self.fetch_all_tickers():
                        # 检测异常波动
                        abnormal = self.detect_abnormal_movements()
                        
                        # 处理异常波动
                        self.process_abnormal_movements(abnormal)
                        
                        # 保存当前数据作为下一次的上一次数据
                        self.previous_data = self.current_data.copy()
                        
                        # 输出异常波动信息
                        if abnormal:
                            for item in abnormal:
                                logger.info(f"异常波动: {item['currency_pair']}, 原因: {', '.join(item['reasons'])}")
                    
                    # 等待下一次检查
                    print(f"\n等待{CHECK_INTERVAL}秒后进行下一次检查...")
                    
                    # 分段等待，以便能够及时响应用户输入
                    wait_start = time.time()
                    while time.time() - wait_start < CHECK_INTERVAL and self.running and not self.paused:
                        time.sleep(0.1)
                
        except KeyboardInterrupt:
            logger.info("收到中断信号，程序退出")
        except Exception as e:
            logger.error(f"程序运行出错: {e}")
        finally:
            logger.info("Gate.io加密货币异动监控系统关闭")

def main():
    """主函数"""
    print("Gate.io加密货币异动监控系统启动")
    
    # 创建并启动监控器
    monitor = CryptoMonitor()
    monitor.start()

if __name__ == "__main__":
    main()
EOF

# 创建启动脚本
echo -e "${YELLOW}正在创建启动脚本...${NC}"
cat > start_monitor.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
python3 src/main.py
EOF

chmod +x start_monitor.sh

# 创建桌面快捷方式
if [ -d "$HOME/Desktop" ]; then
    echo -e "${YELLOW}正在创建桌面快捷方式...${NC}"
    cat > "$HOME/Desktop/CryptoMonitor.desktop" << EOF
[Desktop Entry]
Name=Crypto Monitor
Comment=Gate.io加密货币异动监控系统
Exec=$INSTALL_DIR/start_monitor.sh
Terminal=true
Type=Application
Icon=utilities-terminal
EOF
    chmod +x "$HOME/Desktop/CryptoMonitor.desktop"
fi

# 创建一键启动脚本
echo -e "${YELLOW}正在创建一键启动脚本...${NC}"
cat > "$HOME/启动加密货币监控.sh" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
./start_monitor.sh
EOF
chmod +x "$HOME/启动加密货币监控.sh"

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}               安装成功！                             ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "您可以通过以下方式启动监控系统："
echo -e "1. 双击桌面上的 ${YELLOW}'Crypto Monitor'${NC} 图标"
echo -e "2. 双击主目录中的 ${YELLOW}'启动加密货币监控.sh'${NC} 文件"
echo -e "3. 在终端中运行: ${YELLOW}$INSTALL_DIR/start_monitor.sh${NC}"
echo ""
echo -e "${YELLOW}快捷键功能:${NC}"
echo -e "1. jk = 开启/关闭监控"
echo -e "2. db = 设置Telegram"
echo -e "3. api = 设置API"
echo -e "4. bd = 设置涨幅警报阈值"
echo ""
echo -e "是否现在启动监控系统？(y/n)"
read -p "> " START_NOW

if [[ "$START_NOW" == "y" || "$START_NOW" == "Y" ]]; then
    echo -e "${GREEN}正在启动监控系统...${NC}"
    "$INSTALL_DIR/start_monitor.sh"
else
    echo -e "${GREEN}安装完成！您可以稍后手动启动监控系统。${NC}"
fi
