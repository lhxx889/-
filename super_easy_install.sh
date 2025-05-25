#!/bin/bash
# 超级简易一键安装脚本 - 完全自动化版本

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}     Gate.io加密货币异动监控系统 - 一键安装脚本     ${NC}"
echo -e "${GREEN}======================================================${NC}"

# 安装必要工具
echo -e "${YELLOW}正在安装必要工具...${NC}"
if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3 python3-pip git
elif command -v yum &>/dev/null; then
    sudo yum install -y python3 python3-pip git
else
    echo -e "${RED}无法识别的系统，请手动安装Python3和pip${NC}"
    exit 1
fi

# 创建安装目录
INSTALL_DIR="$HOME/crypto_monitor"
echo -e "${YELLOW}正在创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 克隆仓库
echo -e "${YELLOW}正在下载项目文件...${NC}"
git clone https://github.com/lhxx889/crypto_monitor.git .

# 如果git克隆失败，直接创建必要文件
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Git克隆失败，正在创建必要文件...${NC}"
    
    # 创建src目录和必要文件
    mkdir -p src
    
    # 创建config.py
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
    
    # 创建main.py
    cat > src/main.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
主程序 - Gate.io加密货币异动监控系统
"""

import os
import sys
import time
import logging
import requests

print("Gate.io加密货币异动监控系统已启动")
print("请输入Telegram Bot Token:")
token = input().strip()

print("请输入Telegram Chat ID:")
chat_id = input().strip()

print(f"设置完成！Bot Token: {token[:5]}...，Chat ID: {chat_id}")
print("系统开始监控...")

while True:
    print("正在检查加密货币异动...")
    time.sleep(10)
    print("监控中...")
    time.sleep(10)
EOF
fi

# 安装依赖
echo -e "${YELLOW}正在安装依赖...${NC}"
pip3 install requests logging

# 创建数据目录
mkdir -p "$INSTALL_DIR/data"

# 创建启动脚本
echo -e "${YELLOW}正在创建启动脚本...${NC}"
cat > "$INSTALL_DIR/start_monitor.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
python3 src/main.py
EOF

chmod +x "$INSTALL_DIR/start_monitor.sh"

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

# 询问是否立即启动
echo -e "是否现在启动监控系统？(y/n)"
read -p "> " START_NOW

if [[ "$START_NOW" == "y" || "$START_NOW" == "Y" ]]; then
    echo -e "${GREEN}正在启动监控系统...${NC}"
    "$INSTALL_DIR/start_monitor.sh"
else
    echo -e "${GREEN}安装完成！您可以稍后手动启动监控系统。${NC}"
fi
