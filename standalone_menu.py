#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
独立交互菜单 - Gate.io加密货币异动监控系统
提供独立的交互式菜单，可以在不启动监控的情况下管理系统
"""

import os
import sys
import time
import json
import logging
from typing import Dict, List, Any, Optional

# 设置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("standalone_menu")

# 添加src目录到路径
current_dir = os.path.dirname(os.path.abspath(__file__))
if os.path.basename(current_dir) == "crypto_monitor":
    sys.path.append(current_dir)
else:
    parent_dir = os.path.dirname(current_dir)
    sys.path.append(parent_dir)

try:
    # 尝试导入必要的模块
    from src.api_manager import get_api_manager
    from src.telegram_notifier import TelegramBot
    from src.config import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, DATA_DIR
except ImportError as e:
    logger.error(f"导入模块失败: {e}")
    print(f"错误: 无法导入必要的模块。请确保您在crypto_monitor目录中运行此脚本。")
    print(f"当前目录: {os.getcwd()}")
    print(f"导入错误: {e}")
    sys.exit(1)

class StandaloneMenu:
    """独立交互菜单类"""
    
    def __init__(self):
        self.running = True
        self.api_manager = get_api_manager()
        self.user_config = self.load_user_config()
    
    def load_user_config(self):
        """加载用户配置"""
        default_config = {
            "telegram_bot_token": TELEGRAM_BOT_TOKEN,
            "telegram_chat_id": TELEGRAM_CHAT_ID,
            "last_update": ""
        }
        
        try:
            config_file = os.path.join(DATA_DIR, "user_config.json")
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    config = json.load(f)
                    # 更新默认配置
                    default_config.update(config)
                    logger.info("已加载用户配置")
            else:
                logger.info("未找到用户配置，使用默认配置")
        except Exception as e:
            logger.error(f"加载用户配置失败: {e}")
        
        return default_config
    
    def display_menu(self):
        """显示菜单"""
        print("\n" + "=" * 50)
        print("Gate.io加密货币异动监控系统 - 独立交互菜单")
        print("=" * 50)
        print("1. 查看所有可用API地址")
        print("2. 切换到主API地址")
        print("3. 切换到备用API地址")
        print("4. 添加自定义API地址")
        print("5. 删除自定义API地址")
        print("6. 测试当前API地址连接")
        print("7. 设置Telegram配置")
        print("8. 发送测试消息到Telegram")
        print("9. 启动监控系统")
        print("0. 退出菜单")
        print("=" * 50)
        print("请输入选项编号:")
    
    def handle_menu_choice(self, choice):
        """处理菜单选择"""
        try:
            choice = choice.strip()
            choice = int(choice)
            
            if choice == 1:
                self.show_all_api_urls()
            elif choice == 2:
                self.switch_to_primary_api()
            elif choice == 3:
                self.switch_to_backup_api()
            elif choice == 4:
                self.add_custom_api()
            elif choice == 5:
                self.delete_custom_api()
            elif choice == 6:
                self.test_current_api()
            elif choice == 7:
                self.setup_telegram()
            elif choice == 8:
                self.send_test_message()
            elif choice == 9:
                self.start_monitor()
            elif choice == 0:
                print("退出菜单...")
                self.running = False
            else:
                print("无效选项，请重新输入")
            
            return True
        except ValueError:
            print("无效输入，请输入数字")
            return True
        except Exception as e:
            logger.error(f"处理菜单选择时出错: {e}")
            return True
    
    def show_all_api_urls(self):
        """显示所有可用API地址"""
        print("\n所有可用API地址:")
        print(f"当前API地址: {self.api_manager.current_url}")
        print(f"主API地址: {self.api_manager.primary_url}")
        
        print("\n备用API地址:")
        for i, url in enumerate(self.api_manager.backup_urls, 1):
            print(f"{i}. {url}")
        
        print("\n自定义API地址:")
        custom_urls = self.api_manager.get_custom_urls()
        if custom_urls:
            for i, url in enumerate(custom_urls, 1):
                print(f"{i}. {url}")
        else:
            print("暂无自定义API地址")
    
    def switch_to_primary_api(self):
        """切换到主API地址"""
        if self.api_manager.switch_to_primary():
            print(f"已切换到主API地址: {self.api_manager.current_url}")
        else:
            print("切换失败，请检查网络连接")
    
    def switch_to_backup_api(self):
        """切换到备用API地址"""
        backup_urls = self.api_manager.backup_urls
        if not backup_urls:
            print("没有可用的备用API地址")
            return
        
        print("\n可用的备用API地址:")
        for i, url in enumerate(backup_urls, 1):
            print(f"{i}. {url}")
        
        print("\n请选择要切换的备用API地址编号:")
        try:
            choice = int(input().strip())
            if 1 <= choice <= len(backup_urls):
                url = backup_urls[choice - 1]
                if self.api_manager.switch_to_url(url):
                    print(f"已切换到备用API地址: {url}")
                else:
                    print("切换失败，请检查网络连接")
            else:
                print("无效选项")
        except ValueError:
            print("请输入有效的数字")
    
    def add_custom_api(self):
        """添加自定义API地址"""
        print("\n请输入要添加的自定义API地址:")
        url = input().strip()
        
        if not url:
            print("API地址不能为空")
            return
        
        if self.api_manager.add_custom_url(url):
            print(f"已添加自定义API地址: {url}")
        else:
            print("添加失败，可能是地址格式不正确或已存在")
    
    def delete_custom_api(self):
        """删除自定义API地址"""
        custom_urls = self.api_manager.get_custom_urls()
        if not custom_urls:
            print("没有可删除的自定义API地址")
            return
        
        print("\n可删除的自定义API地址:")
        for i, url in enumerate(custom_urls, 1):
            print(f"{i}. {url}")
        
        print("\n请选择要删除的自定义API地址编号:")
        try:
            choice = int(input().strip())
            if 1 <= choice <= len(custom_urls):
                url = custom_urls[choice - 1]
                if self.api_manager.remove_custom_url(url):
                    print(f"已删除自定义API地址: {url}")
                else:
                    print("删除失败")
            else:
                print("无效选项")
        except ValueError:
            print("请输入有效的数字")
    
    def test_current_api(self):
        """测试当前API地址连接"""
        print(f"\n正在测试当前API地址: {self.api_manager.current_url}")
        
        if self.api_manager.test_connection():
            print("连接测试成功，API地址可用")
        else:
            print("连接测试失败，API地址不可用")
            
            # 询问是否自动切换到可用地址
            print("\n是否自动切换到可用的API地址? (y/n)")
            choice = input().strip().lower()
            
            if choice == 'y':
                if self.api_manager.switch_to_available():
                    print(f"已自动切换到可用的API地址: {self.api_manager.current_url}")
                else:
                    print("没有找到可用的API地址，请检查网络连接")
    
    def setup_telegram(self):
        """设置Telegram配置"""
        print("\n当前Telegram配置:")
        if self.user_config["telegram_bot_token"] and self.user_config["telegram_chat_id"]:
            print(f"Bot Token: {self.user_config['telegram_bot_token'][:5]}...")
            print(f"Chat ID: {self.user_config['telegram_chat_id']}")
        else:
            print("未设置Telegram配置")
        
        print("\n请输入新的Telegram Bot Token (留空保持不变):")
        token = input().strip()
        
        if token:
            self.user_config["telegram_bot_token"] = token
        
        print("请输入新的Telegram Chat ID (留空保持不变):")
        chat_id = input().strip()
        
        if chat_id:
            self.user_config["telegram_chat_id"] = chat_id
        
        # 保存配置
        try:
            self.user_config["last_update"] = time.strftime("%Y-%m-%d %H:%M:%S")
            config_file = os.path.join(DATA_DIR, "user_config.json")
            with open(config_file, 'w') as f:
                json.dump(self.user_config, f)
            print("Telegram配置已保存")
        except Exception as e:
            logger.error(f"保存Telegram配置失败: {e}")
            print(f"保存配置失败: {e}")
    
    def send_test_message(self):
        """发送测试消息到Telegram"""
        if not self.user_config["telegram_bot_token"] or not self.user_config["telegram_chat_id"]:
            print("Telegram未配置，请先设置Telegram配置")
            return
        
        try:
            bot = TelegramBot(self.user_config["telegram_bot_token"])
            message = f"""
<b>🧪 测试消息</b>

这是一条测试消息，用于验证Telegram配置是否正确。

<b>配置信息:</b>
• Bot Token: {self.user_config["telegram_bot_token"][:5]}...
• Chat ID: {self.user_config["telegram_chat_id"]}
• 发送时间: {time.strftime("%Y-%m-%d %H:%M:%S")}

<i>如果您收到此消息，则表示Telegram配置正确。</i>
"""
            
            if bot.send_message(self.user_config["telegram_chat_id"], message):
                print("测试消息发送成功，请检查您的Telegram")
            else:
                print("测试消息发送失败，请检查Telegram配置")
        except Exception as e:
            logger.error(f"发送测试消息失败: {e}")
            print(f"发送测试消息失败: {e}")
    
    def start_monitor(self):
        """启动监控系统"""
        print("\n正在启动监控系统...")
        
        try:
            # 构建启动命令
            script_dir = os.path.dirname(os.path.abspath(__file__))
            if os.path.basename(script_dir) == "crypto_monitor":
                start_script = os.path.join(script_dir, "start_monitor.sh")
            else:
                start_script = os.path.join(os.path.dirname(script_dir), "start_monitor.sh")
            
            if not os.path.exists(start_script):
                print(f"启动脚本不存在: {start_script}")
                return
            
            print("监控系统将在新窗口中启动")
            print("请关闭此菜单窗口并查看新窗口")
            
            # 使用系统命令启动监控
            os.system(f"gnome-terminal -- {start_script}")
            
            # 退出菜单
            self.running = False
        except Exception as e:
            logger.error(f"启动监控系统失败: {e}")
            print(f"启动监控系统失败: {e}")
    
    def run(self):
        """运行菜单"""
        print("欢迎使用Gate.io加密货币异动监控系统独立交互菜单")
        print("此菜单允许您管理系统而不启动监控")
        
        while self.running:
            try:
                self.display_menu()
                choice = input().strip()
                
                if not self.handle_menu_choice(choice):
                    break
                
                time.sleep(0.1)
            except KeyboardInterrupt:
                print("\n收到中断信号，退出菜单...")
                break
            except Exception as e:
                logger.error(f"菜单运行出错: {e}")
                print(f"出错: {e}")
                time.sleep(1)
        
        print("感谢使用，再见！")

if __name__ == "__main__":
    menu = StandaloneMenu()
    menu.run()
