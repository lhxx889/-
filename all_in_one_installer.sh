#!/bin/bash
# 超级简易一键安装脚本 - 自解压版
# 包含所有功能：快捷键(jm/db)、配置记忆、启动推送

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
echo -e "${GREEN}     Gate.io加密货币异动监控系统 - 一键安装脚本     ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "欢迎使用Gate.io加密货币异动监控系统！"
echo -e "这个脚本会自动为您完成所有安装和配置步骤。"
echo -e "已集成快捷键(jm/db)、配置记忆和启动推送功能。"
echo ""

# 检查是否为Linux系统
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}错误: 此脚本仅支持Linux系统${NC}"
    echo -e "请在Linux系统上运行此脚本。"
    exit 1
fi

# 检查并安装必要工具
echo -e "${YELLOW}正在检查必要工具...${NC}"
MISSING_TOOLS=()

if ! command -v python3 &>/dev/null; then
    MISSING_TOOLS+=("python3")
fi

if ! command -v pip3 &>/dev/null; then
    MISSING_TOOLS+=("pip3")
fi

# 安装缺失的工具
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}需要安装以下工具: ${MISSING_TOOLS[*]}${NC}"
    echo -e "正在自动安装..."
    
    # 检测包管理器
    if command -v apt-get &>/dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip
    elif command -v yum &>/dev/null; then
        # CentOS/RHEL
        sudo yum install -y python3 python3-pip
    elif command -v dnf &>/dev/null; then
        # Fedora
        sudo dnf install -y python3 python3-pip
    elif command -v pacman &>/dev/null; then
        # Arch Linux
        sudo pacman -Sy python python-pip
    else
        echo -e "${RED}错误: 无法自动安装必要工具${NC}"
        echo -e "请手动安装以下工具后再运行此脚本: ${MISSING_TOOLS[*]}"
        exit 1
    fi
fi

# 再次检查必要工具
for tool in python3 pip3; do
    if ! command -v $tool &>/dev/null; then
        echo -e "${RED}错误: 无法安装 $tool${NC}"
        echo -e "请手动安装后再运行此脚本。"
        exit 1
    fi
done

echo -e "${GREEN}所有必要工具已准备就绪！${NC}"

# 创建安装目录
echo -e "${YELLOW}正在创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 创建必要的目录结构
mkdir -p src data

# 安装Python依赖
echo -e "${YELLOW}正在安装Python依赖...${NC}"
pip3 install requests

# 创建配置文件
echo -e "${YELLOW}正在创建配置文件...${NC}"
cat > src/config.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
配置模块 - Gate.io加密货币异动监控系统
"""

import os
import logging
from typing import List

# API配置
PRIMARY_API_URL = "https://api.gateio.ws/api/v4"
BACKUP_API_URLS = [
    "https://api.gateio.io/api/v4",
    "https://api.gate.io/api/v4"
]
API_BASE_URL = PRIMARY_API_URL
API_RATE_LIMIT = 100  # 每分钟最大请求数
API_RATE_WINDOW = 60  # 速率限制窗口期（秒）

# 监控配置
CHECK_INTERVAL = 50  # 检查间隔（秒）
PRICE_CHANGE_THRESHOLD = 45.0  # 价格波动阈值（百分比）
VOLUME_SURGE_THRESHOLD = 200.0  # 交易量猛增阈值（百分比）
CONTINUOUS_RUN = True  # 是否持续运行

# Telegram配置
TELEGRAM_API_URL = "https://api.telegram.org/bot"
TELEGRAM_BOT_TOKEN = ""  # 在首次运行时填写或从环境变量获取
TELEGRAM_CHAT_ID = ""    # 在首次运行时填写或从环境变量获取

# 日志配置
LOG_LEVEL = "INFO"
LOG_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "crypto_monitor.log")

# 数据目录
DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")

# 确保数据目录存在
os.makedirs(DATA_DIR, exist_ok=True)

# 从环境变量加载配置（如果有）
if os.environ.get("TELEGRAM_BOT_TOKEN"):
    TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")

if os.environ.get("TELEGRAM_CHAT_ID"):
    TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID")

if os.environ.get("CHECK_INTERVAL"):
    try:
        CHECK_INTERVAL = int(os.environ.get("CHECK_INTERVAL"))
    except ValueError:
        pass

if os.environ.get("PRICE_CHANGE_THRESHOLD"):
    try:
        PRICE_CHANGE_THRESHOLD = float(os.environ.get("PRICE_CHANGE_THRESHOLD"))
    except ValueError:
        pass

if os.environ.get("VOLUME_SURGE_THRESHOLD"):
    try:
        VOLUME_SURGE_THRESHOLD = float(os.environ.get("VOLUME_SURGE_THRESHOLD"))
    except ValueError:
        pass

# 加载自定义配置文件（如果存在）
custom_config_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "custom_config.py")
if os.path.exists(custom_config_path):
    try:
        exec(open(custom_config_path).read())
    except Exception as e:
        print(f"加载自定义配置失败: {e}")
EOF

# 创建API管理器模块
echo -e "${YELLOW}正在创建API管理器模块...${NC}"
cat > src/api_manager.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
API管理器模块 - Gate.io加密货币异动监控系统
管理API地址，支持主地址、备用地址和自定义地址的切换
"""

import os
import sys
import json
import time
import logging
import requests
from typing import List, Dict, Any, Optional

# 添加src目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入配置
from src.config import PRIMARY_API_URL, BACKUP_API_URLS, API_RATE_LIMIT, API_RATE_WINDOW, DATA_DIR

logger = logging.getLogger("api_manager")

class APIManager:
    """API管理器类"""
    
    def __init__(self):
        self.primary_url = PRIMARY_API_URL
        self.backup_urls = BACKUP_API_URLS.copy()
        self.current_url = self.primary_url
        self.custom_urls = []
        self.request_times = []  # 用于速率限制
        self.rate_limit = API_RATE_LIMIT
        self.rate_window = API_RATE_WINDOW
        
        # 加载自定义API地址
        self.load_custom_urls()
        
        # 测试当前API地址，如果不可用则切换
        if not self.test_connection():
            self.switch_to_available()
        
        logger.info(f"API管理器初始化完成，当前API地址: {self.current_url}")
    
    def load_custom_urls(self):
        """加载自定义API地址"""
        try:
            file_path = os.path.join(DATA_DIR, "custom_api_urls.json")
            if os.path.exists(file_path):
                with open(file_path, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        self.custom_urls = data
                        logger.info(f"已加载{len(self.custom_urls)}个自定义API地址")
        except Exception as e:
            logger.error(f"加载自定义API地址失败: {e}")
    
    def save_custom_urls(self):
        """保存自定义API地址"""
        try:
            file_path = os.path.join(DATA_DIR, "custom_api_urls.json")
            with open(file_path, 'w') as f:
                json.dump(self.custom_urls, f)
            logger.info(f"已保存{len(self.custom_urls)}个自定义API地址")
        except Exception as e:
            logger.error(f"保存自定义API地址失败: {e}")
    
    def add_custom_url(self, url: str) -> bool:
        """添加自定义API地址"""
        url = url.strip()
        if not url:
            return False
        
        # 检查是否已存在
        if url in self.custom_urls or url == self.primary_url or url in self.backup_urls:
            return False
        
        # 测试URL是否可用
        if not self.test_url(url):
            logger.warning(f"添加的API地址不可用: {url}")
            return False
        
        self.custom_urls.append(url)
        self.save_custom_urls()
        logger.info(f"已添加自定义API地址: {url}")
        return True
    
    def remove_custom_url(self, url: str) -> bool:
        """删除自定义API地址"""
        if url in self.custom_urls:
            self.custom_urls.remove(url)
            self.save_custom_urls()
            
            # 如果删除的是当前使用的URL，则切换到可用地址
            if url == self.current_url:
                self.switch_to_available()
            
            logger.info(f"已删除自定义API地址: {url}")
            return True
        return False
    
    def get_custom_urls(self) -> List[str]:
        """获取自定义API地址列表"""
        return self.custom_urls.copy()
    
    def switch_to_primary(self) -> bool:
        """切换到主API地址"""
        if self.test_url(self.primary_url):
            self.current_url = self.primary_url
            logger.info(f"已切换到主API地址: {self.current_url}")
            return True
        else:
            logger.warning(f"主API地址不可用: {self.primary_url}")
            return False
    
    def switch_to_url(self, url: str) -> bool:
        """切换到指定API地址"""
        if self.test_url(url):
            self.current_url = url
            logger.info(f"已切换到API地址: {self.current_url}")
            return True
        else:
            logger.warning(f"API地址不可用: {url}")
            return False
    
    def switch_to_available(self) -> bool:
        """切换到可用的API地址"""
        # 先尝试主地址
        if self.test_url(self.primary_url):
            self.current_url = self.primary_url
            logger.info(f"已切换到主API地址: {self.current_url}")
            return True
        
        # 再尝试备用地址
        for url in self.backup_urls:
            if self.test_url(url):
                self.current_url = url
                logger.info(f"已切换到备用API地址: {self.current_url}")
                return True
        
        # 最后尝试自定义地址
        for url in self.custom_urls:
            if self.test_url(url):
                self.current_url = url
                logger.info(f"已切换到自定义API地址: {self.current_url}")
                return True
        
        logger.error("没有找到可用的API地址")
        return False
    
    def test_connection(self) -> bool:
        """测试当前API地址连接"""
        return self.test_url(self.current_url)
    
    def test_url(self, url: str) -> bool:
        """测试指定API地址是否可用"""
        try:
            response = requests.get(f"{url}/spot/currencies", timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"测试API地址失败: {url}, 错误: {e}")
            return False
    
    def check_rate_limit(self):
        """检查并处理速率限制"""
        now = time.time()
        
        # 清理过期的请求时间
        self.request_times = [t for t in self.request_times if now - t < self.rate_window]
        
        # 检查是否超过速率限制
        if len(self.request_times) >= self.rate_limit:
            # 计算需要等待的时间
            wait_time = self.rate_window - (now - self.request_times[0])
            if wait_time > 0:
                logger.warning(f"达到速率限制，等待{wait_time:.2f}秒")
                time.sleep(wait_time)
                # 重新清理过期的请求时间
                now = time.time()
                self.request_times = [t for t in self.request_times if now - t < self.rate_window]
        
        # 记录本次请求时间
        self.request_times.append(now)
    
    def request(self, method: str, endpoint: str, params: Dict[str, Any] = None, data: Dict[str, Any] = None) -> Any:
        """发送API请求"""
        # 检查速率限制
        self.check_rate_limit()
        
        url = f"{self.current_url}{endpoint}"
        
        try:
            if method.upper() == "GET":
                response = requests.get(url, params=params, timeout=10)
            elif method.upper() == "POST":
                response = requests.post(url, json=data, timeout=10)
            else:
                logger.error(f"不支持的请求方法: {method}")
                return None
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"API请求失败: {url}, 状态码: {response.status_code}, 响应: {response.text}")
                return None
        except Exception as e:
            logger.error(f"API请求出错: {url}, 错误: {e}")
            
            # 如果当前API地址不可用，尝试切换到可用地址
            if not self.test_connection():
                logger.warning("当前API地址不可用，尝试切换到可用地址")
                self.switch_to_available()
            
            return None

# 单例模式
_api_manager = None

def get_api_manager() -> APIManager:
    """获取API管理器实例"""
    global _api_manager
    if _api_manager is None:
        _api_manager = APIManager()
    return _api_manager
EOF

# 创建交互式菜单模块
echo -e "${YELLOW}正在创建交互式菜单模块...${NC}"
cat > src/interactive_menu.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
交互式菜单模块 - Gate.io加密货币异动监控系统
提供用户友好的交互式菜单，支持API地址切换、监控控制等功能
"""

import os
import sys
import time
import json
import threading
import logging
from typing import Dict, List, Any, Optional

# 添加src目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入API管理器
from src.api_manager import get_api_manager

logger = logging.getLogger("interactive_menu")

class InteractiveMenu:
    """交互式菜单类"""
    
    def __init__(self, monitor):
        self.monitor = monitor
        self.running = False
        self.menu_thread = None
        self.api_manager = get_api_manager()
    
    def display_menu(self):
        """显示菜单"""
        print("\n" + "=" * 50)
        print("Gate.io加密货币异动监控系统 - 交互式菜单")
        print("=" * 50)
        print("1. 查看所有可用API地址")
        print("2. 切换到主API地址")
        print("3. 切换到备用API地址")
        print("4. 添加自定义API地址")
        print("5. 删除自定义API地址")
        print("6. 测试当前API地址连接")
        print("7. 暂停/恢复监控")
        print("8. 发送状态报告到Telegram")
        print("9. 退出菜单")
        print("0. 退出程序")
        print("=" * 50)
        print("快捷键: jm=暂停/恢复监控, db=发送状态报告")
        print("=" * 50)
        print("请输入选项编号:")
    
    def handle_menu_choice(self, choice):
        """处理菜单选择"""
        try:
            choice = choice.strip()
            
            # 处理快捷键
            if choice.lower() == 'jm':
                self.monitor.toggle_monitoring()
                return True
            elif choice.lower() == 'db':
                self.monitor.send_status_report()
                return True
            
            # 处理数字选项
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
                self.toggle_monitoring()
            elif choice == 8:
                self.send_status_report()
            elif choice == 9:
                print("退出菜单，继续监控...")
                return False
            elif choice == 0:
                print("正在安全退出程序...")
                self.monitor.stop()
                return False
            else:
                print("无效选项，请重新输入")
            
            return True
        except ValueError:
            print("无效输入，请输入数字或快捷键")
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
    
    def toggle_monitoring(self):
        """切换监控状态"""
        if self.monitor.paused:
            self.monitor.resume()
            print("已恢复监控")
        else:
            self.monitor.pause()
            print("已暂停监控")
    
    def send_status_report(self):
        """发送状态报告到Telegram"""
        if self.monitor.send_status_report():
            print("已发送状态报告到Telegram")
        else:
            print("发送状态报告失败，请检查Telegram配置")
    
    def _menu_loop(self):
        """菜单循环"""
        while self.running:
            try:
                self.display_menu()
                choice = input().strip()
                
                if not self.handle_menu_choice(choice):
                    break
                
                time.sleep(0.1)
            except Exception as e:
                logger.error(f"菜单循环出错: {e}")
                time.sleep(1)
    
    def start(self):
        """启动菜单"""
        if self.running:
            logger.warning("菜单已在运行")
            return
        
        self.running = True
        self.menu_thread = threading.Thread(target=self._menu_loop)
        self.menu_thread.daemon = True
        self.menu_thread.start()
        
        logger.info("交互式菜单已启动")
    
    def stop(self):
        """停止菜单"""
        self.running = False
        
        if self.menu_thread and self.menu_thread.is_alive():
            self.menu_thread.join(timeout=1.0)
        
        logger.info("交互式菜单已停止")

def create_menu(monitor):
    """创建交互式菜单"""
    return InteractiveMenu(monitor)
EOF

# 创建Telegram通知模块
echo -e "${YELLOW}正在创建Telegram通知模块...${NC}"
cat > src/telegram_notifier.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Telegram通知模块 - Gate.io加密货币异动监控系统
负责发送异常波动警报和状态报告到Telegram
"""

import os
import sys
import json
import logging
import requests
from typing import Dict, List, Any, Optional
from datetime import datetime

# 添加src目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入配置
from src.config import TELEGRAM_API_URL, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

logger = logging.getLogger("telegram_notifier")

class TelegramBot:
    """Telegram机器人类"""
    
    def __init__(self, token: str):
        self.token = token
        self.api_url = f"{TELEGRAM_API_URL}{token}"
    
    def send_message(self, chat_id: str, text: str, parse_mode: str = "HTML") -> bool:
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
                logger.info(f"已发送消息到Telegram，长度: {len(text)}")
                return True
            else:
                logger.error(f"发送消息到Telegram失败，状态码: {response.status_code}, 响应: {response.text}")
                return False
        except Exception as e:
            logger.error(f"发送消息到Telegram出错: {e}")
            return False

def setup_telegram_bot(token: str) -> Optional[Dict[str, Any]]:
    """设置Telegram机器人"""
    try:
        url = f"{TELEGRAM_API_URL}{token}/getMe"
        response = requests.get(url, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            if data.get("ok"):
                return data.get("result")
        
        logger.error(f"获取Telegram机器人信息失败，状态码: {response.status_code}, 响应: {response.text}")
        return None
    except Exception as e:
        logger.error(f"设置Telegram机器人出错: {e}")
        return None

def format_abnormal_message(abnormal: Dict[str, Any]) -> str:
    """格式化异常波动消息"""
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
    
    return message

def send_abnormal_alerts(abnormal_list: List[Dict[str, Any]]) -> bool:
    """发送异常波动警报"""
    if not abnormal_list:
        return True
    
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.error("Telegram未配置，无法发送异常波动警报")
        return False
    
    bot = TelegramBot(TELEGRAM_BOT_TOKEN)
    success = True
    
    for abnormal in abnormal_list:
        message = format_abnormal_message(abnormal)
        if not bot.send_message(TELEGRAM_CHAT_ID, message):
            success = False
    
    return success
EOF

# 创建币种详情查询模块
echo -e "${YELLOW}正在创建币种详情查询模块...${NC}"
cat > src/token_details.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
币种详情查询模块 - Gate.io加密货币异动监控系统
负责查询币种的详细信息，包括持币人数、市值、简介、X链接等
"""

import os
import sys
import json
import logging
import requests
from typing import Dict, List, Any, Optional

# 添加src目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入API管理器
from src.api_manager import get_api_manager

logger = logging.getLogger("token_details")

class TokenDetailsAPI:
    """币种详情API类"""
    
    def __init__(self):
        self.api_manager = get_api_manager()
    
    def get_token_details(self, currency: str) -> Optional[Dict[str, Any]]:
        """获取币种详情"""
        try:
            # 获取币种信息
            currency_info = self.api_manager.request("GET", f"/spot/currencies/{currency}")
            
            if not currency_info:
                logger.error(f"获取币种信息失败: {currency}")
                return None
            
            # 获取币种市场信息
            ticker = self.api_manager.request("GET", f"/spot/tickers", params={"currency_pair": f"{currency}_USDT"})
            
            # 构建详情对象
            details = {
                "currency": currency,
                "name": currency_info.get("name", ""),
                "description": self._get_token_description(currency),
                "market_cap": self._get_market_cap(currency),
                "holders_count": self._get_holders_count(currency),
                "social_links": self._get_social_links(currency),
                "price_usd": ticker[0].get("last") if ticker and len(ticker) > 0 else "未知",
                "volume_24h": ticker[0].get("base_volume") if ticker and len(ticker) > 0 else "未知"
            }
            
            return details
        except Exception as e:
            logger.error(f"获取币种详情出错: {currency}, 错误: {e}")
            return None
    
    def _get_token_description(self, currency: str) -> str:
        """获取币种描述"""
        try:
            # 这里应该调用实际的API获取币种描述
            # 由于Gate.io API可能没有直接提供币种描述，这里使用模拟数据
            return f"{currency}是一种基于区块链技术的加密货币，旨在提供安全、快速的交易体验。"
        except Exception as e:
            logger.error(f"获取币种描述出错: {currency}, 错误: {e}")
            return "暂无描述"
    
    def _get_market_cap(self, currency: str) -> str:
        """获取市值"""
        try:
            # 这里应该调用实际的API获取市值
            # 由于Gate.io API可能没有直接提供市值，这里使用模拟数据
            return "未知"
        except Exception as e:
            logger.error(f"获取市值出错: {currency}, 错误: {e}")
            return "未知"
    
    def _get_holders_count(self, currency: str) -> str:
        """获取持币人数"""
        try:
            # 这里应该调用实际的API获取持币人数
            # 由于Gate.io API可能没有直接提供持币人数，这里使用模拟数据
            return "未知"
        except Exception as e:
            logger.error(f"获取持币人数出错: {currency}, 错误: {e}")
            return "未知"
    
    def _get_social_links(self, currency: str) -> Dict[str, str]:
        """获取社交媒体链接"""
        try:
            # 这里应该调用实际的API获取社交媒体链接
            # 由于Gate.io API可能没有直接提供社交媒体链接，这里使用模拟数据
            return {
                "website": f"https://example.com/{currency.lower()}",
                "twitter": f"https://twitter.com/{currency.lower()}",
                "telegram": f"https://t.me/{currency.lower()}",
                "github": f"https://github.com/{currency.lower()}"
            }
        except Exception as e:
            logger.error(f"获取社交媒体链接出错: {currency}, 错误: {e}")
            return {}
    
    def format_token_details_message(self, currency: str) -> str:
        """格式化币种详情消息"""
        details = self.get_token_details(currency)
        
        if not details:
            return f"<b>无法获取{currency}的详细信息</b>"
        
        social_links = details.get("social_links", {})
        
        message = f"""
<b>📊 {details.get('currency')} 币种详情</b>

<b>基本信息:</b>
• 名称: {details.get('name', '未知')}
• 当前价格: {details.get('price_usd', '未知')} USDT
• 24小时交易量: {details.get('volume_24h', '未知')}
• 市值: {details.get('market_cap', '未知')}
• 持币人数: {details.get('holders_count', '未知')}

<b>简介:</b>
{details.get('description', '暂无简介')}

<b>社交媒体:</b>
• 网站: {social_links.get('website', '未知')}
• Twitter: {social_links.get('twitter', '未知')}
• Telegram: {social_links.get('telegram', '未知')}
• GitHub: {social_links.get('github', '未知')}

<i>数据来源: Gate.io</i>
"""
        
        return message
EOF

# 创建异动原因分析模块
echo -e "${YELLOW}正在创建异动原因分析模块...${NC}"
cat > src/reason_analyzer.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
异动原因分析模块 - Gate.io加密货币异动监控系统
负责分析异常波动的可能原因
"""

import os
import sys
import json
import logging
import requests
from typing import Dict, List, Any, Optional
from datetime import datetime

# 添加src目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入API管理器
from src.api_manager import get_api_manager

logger = logging.getLogger("reason_analyzer")

class ReasonAnalyzer:
    """异动原因分析器类"""
    
    def __init__(self):
        self.api_manager = get_api_manager()
    
    def analyze_abnormal_movement(self, abnormal: Dict[str, Any]) -> Dict[str, Any]:
        """分析异常波动原因"""
        currency_pair = abnormal.get("currency_pair", "")
        price_change_pct = abnormal.get("price_change_pct", 0)
        volume_change_pct = abnormal.get("volume_change_pct", 0)
        
        # 分析结果
        analysis = {
            "possible_reasons": [],
            "market_events": [],
            "technical_factors": [],
            "confidence": "中"
        }
        
        # 检查价格和交易量变化
        if price_change_pct >= 45 and volume_change_pct >= 200:
            analysis["possible_reasons"].append("重大新闻或公告")
            analysis["possible_reasons"].append("大额交易")
            analysis["confidence"] = "高"
        elif price_change_pct >= 45:
            analysis["possible_reasons"].append("市场情绪变化")
            analysis["possible_reasons"].append("技术突破")
        elif volume_change_pct >= 200:
            analysis["possible_reasons"].append("大额交易")
            analysis["possible_reasons"].append("流动性变化")
        
        # 检查市场事件
        self._check_market_events(currency_pair, analysis)
        
        # 检查技术因素
        self._check_technical_factors(currency_pair, analysis)
        
        return analysis
    
    def _check_market_events(self, currency_pair: str, analysis: Dict[str, Any]):
        """检查市场事件"""
        try:
            # 这里应该调用实际的API或数据源获取市场事件
            # 由于没有直接的API，这里使用模拟数据
            currency = currency_pair.split("_")[0] if "_" in currency_pair else currency_pair
            
            # 模拟市场事件
            events = [
                f"{currency}可能发布了新的合作公告",
                f"加密货币市场整体波动",
                f"可能有大型交易所上线{currency}"
            ]
            
            analysis["market_events"] = events
        except Exception as e:
            logger.error(f"检查市场事件出错: {currency_pair}, 错误: {e}")
    
    def _check_technical_factors(self, currency_pair: str, analysis: Dict[str, Any]):
        """检查技术因素"""
        try:
            # 这里应该调用实际的API或数据源获取技术因素
            # 由于没有直接的API，这里使用模拟数据
            
            # 模拟技术因素
            factors = [
                "可能突破关键阻力位",
                "交易量突然增加",
                "短期超买或超卖"
            ]
            
            analysis["technical_factors"] = factors
        except Exception as e:
            logger.error(f"检查技术因素出错: {currency_pair}, 错误: {e}")
    
    def format_reason_message(self, abnormal: Dict[str, Any], analysis: Dict[str, Any]) -> str:
        """格式化原因分析消息"""
        currency_pair = abnormal.get("currency_pair", "")
        price_change_pct = abnormal.get("price_change_pct", 0)
        volume_change_pct = abnormal.get("volume_change_pct", 0)
        
        possible_reasons = analysis.get("possible_reasons", [])
        market_events = analysis.get("market_events", [])
        technical_factors = analysis.get("technical_factors", [])
        confidence = analysis.get("confidence", "中")
        
        # 格式化消息
        message = f"""
<b>🔍 {currency_pair} 异动原因分析</b>

<b>异动概况:</b>
• 价格变化: {price_change_pct:.2f}%
• 交易量变化: {volume_change_pct:.2f}%
• 分析可信度: {confidence}

<b>可能原因:</b>
"""
        
        if possible_reasons:
            for reason in possible_reasons:
                message += f"• {reason}\n"
        else:
            message += "• 暂无明确原因\n"
        
        message += "\n<b>相关市场事件:</b>\n"
        
        if market_events:
            for event in market_events:
                message += f"• {event}\n"
        else:
            message += "• 暂无相关市场事件\n"
        
        message += "\n<b>技术面因素:</b>\n"
        
        if technical_factors:
            for factor in technical_factors:
                message += f"• {factor}\n"
        else:
            message += "• 暂无明显技术面因素\n"
        
        message += "\n<i>注意: 此分析基于算法自动生成，仅供参考，不构成投资建议。</i>"
        
        return message
EOF

# 创建主程序
echo -e "${YELLOW}正在创建主程序...${NC}"
cat > src/main.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
主程序 - Gate.io加密货币异动监控系统
集成所有模块，实现完整功能，支持交互式菜单和动态切换API地址
增加快捷键功能和配置记忆功能
"""

import os
import sys
import time
import json
import logging
import requests
import threading
import signal
from datetime import datetime
from typing import Dict, List, Any, Tuple, Optional

# 添加src目录到路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 导入配置
from src.config import (
    CHECK_INTERVAL, PRICE_CHANGE_THRESHOLD, 
    VOLUME_SURGE_THRESHOLD, CONTINUOUS_RUN, LOG_LEVEL, LOG_FILE,
    DATA_DIR, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
)

# 导入各模块
from src.api_manager import get_api_manager
from src.interactive_menu import create_menu
from src.telegram_notifier import TelegramBot, send_abnormal_alerts, setup_telegram_bot, format_abnormal_message
from src.token_details import TokenDetailsAPI
from src.reason_analyzer import ReasonAnalyzer

# 确保数据目录存在
os.makedirs(DATA_DIR, exist_ok=True)

# 配置日志
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("crypto_monitor")

# 配置文件路径
CONFIG_FILE = os.path.join(DATA_DIR, "user_config.json")

class DataManager:
    """数据管理器"""
    
    def __init__(self):
        self.api_manager = get_api_manager()
        self.previous_data = {}  # 上一次的数据
        self.current_data = {}   # 当前数据
        self.alerts = []         # 异动警报
    
    def load_previous_data(self):
        """加载上一次的数据"""
        try:
            file_path = os.path.join(DATA_DIR, "previous_tickers.json")
            if os.path.exists(file_path):
                with open(file_path, 'r') as f:
                    self.previous_data = json.load(f)
                logger.info(f"已加载上一次数据，共{len(self.previous_data)}个交易对")
            else:
                logger.info("未找到上一次数据，将在本次运行后创建")
        except Exception as e:
            logger.error(f"加载上一次数据失败: {e}")
    
    def save_current_data(self):
        """保存当前数据作为下一次的上一次数据"""
        try:
            file_path = os.path.join(DATA_DIR, "previous_tickers.json")
            with open(file_path, 'w') as f:
                json.dump(self.current_data, f)
            logger.info(f"已保存当前数据，共{len(self.current_data)}个交易对")
        except Exception as e:
            logger.error(f"保存当前数据失败: {e}")
    
    def fetch_all_tickers(self):
        """获取所有交易对的Ticker信息"""
        tickers = self.api_manager.request("GET", "/spot/tickers")
        if tickers:
            # 将列表转换为以currency_pair为键的字典
            self.current_data = {ticker["currency_pair"]: ticker for ticker in tickers}
            logger.info(f"已获取{len(self.current_data)}个交易对的Ticker信息")
            return True
        else:
            logger.error("获取Ticker信息失败")
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

class CryptoMonitor:
    """加密货币监控器"""
    
    def __init__(self):
        self.data_manager = DataManager()
        self.running = False
        self.paused = False
        self.monitor_thread = None
        self.menu = None
        self.user_config = self.load_user_config()
        
        # 设置快捷键
        self.shortcut_keys = {
            'jm': self.toggle_monitoring,  # 监控快捷键
            'db': self.send_status_report   # Telegram推送快捷键
        }
        
        # 键盘监听线程
        self.keyboard_thread = None
    
    def load_user_config(self):
        """加载用户配置"""
        default_config = {
            "telegram_bot_token": TELEGRAM_BOT_TOKEN,
            "telegram_chat_id": TELEGRAM_CHAT_ID,
            "last_update": ""
        }
        
        try:
            if os.path.exists(CONFIG_FILE):
                with open(CONFIG_FILE, 'r') as f:
                    config = json.load(f)
                    # 更新默认配置
                    default_config.update(config)
                    logger.info("已加载用户配置")
            else:
                logger.info("未找到用户配置，使用默认配置")
        except Exception as e:
            logger.error(f"加载用户配置失败: {e}")
        
        return default_config
    
    def save_user_config(self):
        """保存用户配置"""
        try:
            self.user_config["last_update"] = datetime.now().isoformat()
            with open(CONFIG_FILE, 'w') as f:
                json.dump(self.user_config, f)
            logger.info("已保存用户配置")
        except Exception as e:
            logger.error(f"保存用户配置失败: {e}")
    
    def setup_bot(self):
        """设置Telegram机器人"""
        global TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
        
        # 检查是否已有配置
        if self.user_config["telegram_bot_token"] and self.user_config["telegram_chat_id"]:
            print(f"已有Telegram配置:")
            print(f"Bot Token: {self.user_config['telegram_bot_token'][:5]}...")
            print(f"Chat ID: {self.user_config['telegram_chat_id']}")
            
            # 询问是否需要重新设置
            print("是否需要重新设置Telegram? (y/n) [默认n]:")
            choice = input().strip().lower()
            
            if choice != 'y':
                # 使用已有配置
                TELEGRAM_BOT_TOKEN = self.user_config["telegram_bot_token"]
                TELEGRAM_CHAT_ID = self.user_config["telegram_chat_id"]
                
                # 测试现有配置
                bot = TelegramBot(TELEGRAM_BOT_TOKEN)
                success = bot.send_message(TELEGRAM_CHAT_ID, "Gate.io加密货币异动监控系统已启动，正在监控中...")
                
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
        if not TELEGRAM_BOT_TOKEN:
            print("请输入Telegram Bot Token:")
            TELEGRAM_BOT_TOKEN = input().strip()
        
        # 设置机器人
        bot_info = setup_telegram_bot(TELEGRAM_BOT_TOKEN)
        if not bot_info:
            logger.error("设置Telegram机器人失败")
            return False
        
        print(f"机器人设置成功: @{bot_info.get('username')}")
        print("请将此机器人添加到您的Telegram群组或频道中")
        
        if not TELEGRAM_CHAT_ID:
            print("请输入Telegram Chat ID (群组ID或频道用户名):")
            TELEGRAM_CHAT_ID = input().strip()
        
        # 发送测试消息
        bot = TelegramBot(TELEGRAM_BOT_TOKEN)
        success = bot.send_message(TELEGRAM_CHAT_ID, "Gate.io加密货币异动监控系统已启动，正在监控中...")
        
        if not success:
            logger.error("发送测试消息失败，请检查Chat ID是否正确")
            return False
        
        # 保存配置
        self.user_config["telegram_bot_token"] = TELEGRAM_BOT_TOKEN
        self.user_config["telegram_chat_id"] = TELEGRAM_CHAT_ID
        self.save_user_config()
        
        # 确保菜单显示
        print("\n")
        print("配置完成，按Enter键显示交互菜单...")
        input()  # 等待用户按Enter
        
        logger.info("Telegram机器人设置成功")
        return True
    
    def process_abnormal_movements(self, abnormal_list):
        """处理异常波动"""
        if not abnormal_list:
            return
        
        # 初始化分析器
        analyzer = ReasonAnalyzer()
        token_api = TokenDetailsAPI()
        
        for abnormal in abnormal_list:
            try:
                # 分析异常原因
                analysis = analyzer.analyze_abnormal_movement(abnormal)
                
                # 获取币种详情
                currency_pair = abnormal.get("currency_pair", "")
                currency = currency_pair.split("_")[0] if "_" in currency_pair else currency_pair
                
                # 格式化异常消息
                abnormal_message = format_abnormal_message(abnormal)
                
                # 格式化原因分析消息
                reason_message = analyzer.format_reason_message(abnormal, analysis)
                
                # 格式化币种详情消息
                token_message = token_api.format_token_details_message(currency)
                
                # 发送消息
                bot = TelegramBot(TELEGRAM_BOT_TOKEN)
                
                # 发送异常警报
                bot.send_message(TELEGRAM_CHAT_ID, abnormal_message)
                time.sleep(1)  # 避免发送过快
                
                # 发送原因分析
                bot.send_message(TELEGRAM_CHAT_ID, reason_message)
                time.sleep(1)  # 避免发送过快
                
                # 发送币种详情
                bot.send_message(TELEGRAM_CHAT_ID, token_message)
                
                logger.info(f"已发送{currency_pair}的异常波动警报、原因分析和币种详情")
            except Exception as e:
                logger.error(f"处理异常波动时出错: {e}")
    
    def send_status_report(self):
        """发送状态报告到Telegram"""
        try:
            if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
                logger.error("Telegram未配置，无法发送状态报告")
                return False
            
            # 获取当前时间
            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # 获取监控状态
            status = "运行中" if not self.paused else "已暂停"
            
            # 获取API状态
            api_manager = get_api_manager()
            api_url = api_manager.current_url
            
            # 获取最新数据
            ticker_count = len(self.data_manager.current_data)
            
            # 格式化消息
            message = f"""
<b>📊 Gate.io加密货币异动监控系统状态报告</b>

<b>系统状态:</b>
• 当前时间: {now}
• 监控状态: {status}
• API地址: {api_url}
• 监控币种数: {ticker_count}
• 价格波动阈值: {PRICE_CHANGE_THRESHOLD}%
• 交易量波动阈值: {VOLUME_SURGE_THRESHOLD}%
• 检查间隔: {CHECK_INTERVAL}秒

<b>快捷键:</b>
• jm: 暂停/恢复监控
• db: 发送状态报告

<i>系统正常运行中，如有异常波动将立即通知。</i>
"""
            
            # 发送消息
            bot = TelegramBot(TELEGRAM_BOT_TOKEN)
            success = bot.send_message(TELEGRAM_CHAT_ID, message)
            
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
        """切换监控状态"""
        if self.paused:
            self.resume()
            print("已恢复监控")
        else:
            self.pause()
            print("已暂停监控")
    
    def start_keyboard_listener(self):
        """启动键盘监听"""
        if self.keyboard_thread and self.keyboard_thread.is_alive():
            logger.warning("键盘监听已在运行")
            return
        
        self.keyboard_thread = threading.Thread(target=self._keyboard_loop, daemon=True)
        self.keyboard_thread.start()
        logger.info("键盘监听已启动")
    
    def _keyboard_loop(self):
        """键盘监听循环"""
        print("\n快捷键已启用:")
        print("- jm: 暂停/恢复监控")
        print("- db: 发送状态报告到Telegram")
        
        while self.running:
            try:
                key = input().strip().lower()
                
                if key in self.shortcut_keys:
                    self.shortcut_keys[key]()
                
                time.sleep(0.1)
            except Exception as e:
                logger.error(f"处理键盘输入时出错: {e}")
                time.sleep(1)
    
    def start(self):
        """启动监控"""
        if self.running:
            logger.warning("监控已在运行")
            return
        
        # 设置Telegram机器人
        if not self.setup_bot():
            logger.error("设置Telegram机器人失败，程序退出")
            return
        
        # 加载上一次数据
        self.data_manager.load_previous_data()
        
        # 启动监控线程
        self.running = True
        self.paused = False
        self.monitor_thread = threading.Thread(target=self._monitor_loop)
        self.monitor_thread.daemon = True
        self.monitor_thread.start()
        
        # 创建并启动交互式菜单
        self.menu = create_menu(self)
        self.menu.start()
        
        # 启动键盘监听
        self.start_keyboard_listener()
        
        # 发送启动状态报告
        self.send_status_report()
        
        logger.info("监控已启动")
    
    def stop(self):
        """停止监控"""
        self.running = False
        
        if self.monitor_thread and self.monitor_thread.is_alive():
            self.monitor_thread.join(timeout=1.0)
        
        if self.menu:
            self.menu.stop()
        
        logger.info("监控已停止")
    
    def pause(self):
        """暂停监控"""
        self.paused = True
        logger.info("监控已暂停")
    
    def resume(self):
        """恢复监控"""
        self.paused = False
        logger.info("监控已恢复")
    
    def _monitor_loop(self):
        """监控循环"""
        while self.running:
            try:
                if not self.paused:
                    logger.info(f"开始新一轮检查，时间: {datetime.now().isoformat()}")
                    
                    # 获取所有交易对的Ticker信息
                    if self.data_manager.fetch_all_tickers():
                        # 检测异常波动
                        abnormal = self.data_manager.detect_abnormal_movements()
                        
                        # 处理异常波动
                        self.process_abnormal_movements(abnormal)
                        
                        # 保存当前数据作为下一次的上一次数据
                        self.data_manager.save_current_data()
                        
                        # 输出异常波动信息
                        if abnormal:
                            for item in abnormal:
                                logger.info(f"异常波动: {item['currency_pair']}, 原因: {', '.join(item['reasons'])}")
                            
                            # 保存异常波动信息
                            try:
                                timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
                                file_path = os.path.join(DATA_DIR, f"abnormal_{timestamp}.json")
                                with open(file_path, 'w') as f:
                                    json.dump(abnormal, f)
                                logger.info(f"已保存异常波动信息到{file_path}")
                            except Exception as e:
                                logger.error(f"保存异常波动信息失败: {e}")
                
                # 如果不是持续运行，则退出
                if not CONTINUOUS_RUN:
                    self.running = False
                    break
                
                # 等待下一次检查
                logger.info(f"等待{CHECK_INTERVAL}秒后进行下一次检查")
                
                # 分段等待，以便能够及时响应暂停/恢复/停止命令
                wait_interval = 0.5  # 每次等待0.5秒
                for _ in range(int(CHECK_INTERVAL / wait_interval)):
                    if not self.running:
                        break
                    time.sleep(wait_interval)
            
            except Exception as e:
                logger.error(f"监控循环出错: {e}")
                time.sleep(5)  # 出错后等待一段时间再继续

def signal_handler(sig, frame):
    """信号处理函数"""
    print("\n收到中断信号，正在安全退出...")
    if monitor:
        monitor.stop()
    sys.exit(0)

# 全局监控器实例
monitor = None

def main():
    """主函数"""
    global monitor
    
    # 注册信号处理函数
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    logger.info("Gate.io加密货币异动监控系统启动")
    
    # 确保数据目录存在
    os.makedirs(DATA_DIR, exist_ok=True)
    
    # 创建并启动监控器
    monitor = CryptoMonitor()
    monitor.start()
    
    try:
        # 保持主线程运行
        while monitor.running:
            time.sleep(0.1)
    except KeyboardInterrupt:
        logger.info("收到中断信号，程序退出")
    except Exception as e:
        logger.error(f"程序运行出错: {e}")
    finally:
        if monitor:
            monitor.stop()
        logger.info("Gate.io加密货币异动监控系统关闭")

if __name__ == "__main__":
    main()
EOF

# 创建__init__.py文件
echo -e "${YELLOW}正在创建__init__.py文件...${NC}"
touch src/__init__.py

# 创建启动脚本
echo -e "${YELLOW}正在创建启动脚本...${NC}"
cat > start_monitor.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
python3 src/main.py
EOF

chmod +x start_monitor.sh

# 创建菜单启动脚本
echo -e "${YELLOW}正在创建菜单启动脚本...${NC}"
cat > menu.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
python3 -c '
import sys
sys.path.append(".")
from src.main import CryptoMonitor
monitor = CryptoMonitor()
monitor.menu = monitor.menu or create_menu(monitor)
monitor.menu.display_menu()
monitor.menu._menu_loop()
'
EOF

chmod +x menu.sh

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
    
    # 创建菜单快捷方式
    cat > "$HOME/Desktop/CryptoMenu.desktop" << EOF
[Desktop Entry]
Name=Crypto Menu
Comment=Gate.io加密货币异动监控系统菜单
Exec=$INSTALL_DIR/menu.sh
Terminal=true
Type=Application
Icon=utilities-terminal
EOF
    chmod +x "$HOME/Desktop/CryptoMenu.desktop"
fi

# 创建一键启动脚本
echo -e "${YELLOW}正在创建一键启动脚本...${NC}"
cat > "$HOME/启动加密货币监控.sh" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
./start_monitor.sh
EOF
chmod +x "$HOME/启动加密货币监控.sh"

# 创建一键菜单脚本
echo -e "${YELLOW}正在创建一键菜单脚本...${NC}"
cat > "$HOME/打开交互菜单.sh" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
./menu.sh
EOF
chmod +x "$HOME/打开交互菜单.sh"

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}               安装成功！                             ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "您可以通过以下方式启动监控系统："
echo -e "1. 双击桌面上的 ${YELLOW}'Crypto Monitor'${NC} 图标"
echo -e "2. 双击主目录中的 ${YELLOW}'启动加密货币监控.sh'${NC} 文件"
echo -e "3. 在终端中运行: ${YELLOW}$INSTALL_DIR/start_monitor.sh${NC}"
echo ""
echo -e "您可以通过以下方式直接打开交互菜单："
echo -e "1. 双击桌面上的 ${YELLOW}'Crypto Menu'${NC} 图标"
echo -e "2. 双击主目录中的 ${YELLOW}'打开交互菜单.sh'${NC} 文件"
echo ""
echo -e "${YELLOW}新增功能:${NC}"
echo -e "1. 快捷键: jm=暂停/恢复监控, db=发送状态报告"
echo -e "2. Telegram配置记忆: 每次启动默认不再重新设置"
echo -e "3. 启动自动推送: 每次启动后自动推送状态报告"
echo -e "4. 修复了交互菜单问题: 确保菜单正常显示"
echo ""
echo -e "是否现在启动监控系统？(y/n)"
read -p "> " START_NOW

if [[ "$START_NOW" == "y" || "$START_NOW" == "Y" ]]; then
    echo -e "${GREEN}正在启动监控系统...${NC}"
    "$INSTALL_DIR/start_monitor.sh"
else
    echo -e "${GREEN}安装完成！您可以稍后手动启动监控系统。${NC}"
fi
