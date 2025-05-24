#!/bin/bash
# 超级简易一键安装脚本 - Gate.io加密货币异动监控系统
# 专为小白用户设计，无需任何技术知识

# 显示彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}     Gate.io加密货币异动监控系统 - 小白专用安装脚本     ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "欢迎使用Gate.io加密货币异动监控系统！"
echo -e "这个脚本会自动为您完成所有安装和配置步骤。"
echo -e "您只需要按照提示操作即可。"
echo ""
echo -e "${YELLOW}正在准备安装环境...${NC}"
sleep 2

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# 检查是否为Linux系统
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}错误: 此脚本仅支持Linux系统${NC}"
    echo -e "请在Linux系统上运行此脚本。"
    exit 1
fi

# 检查必要工具
echo -e "${YELLOW}正在检查必要工具...${NC}"
MISSING_TOOLS=()

if ! command -v python3 &>/dev/null; then
    MISSING_TOOLS+=("python3")
fi

if ! command -v pip3 &>/dev/null; then
    MISSING_TOOLS+=("pip3")
fi

if ! command -v wget &>/dev/null; then
    MISSING_TOOLS+=("wget")
fi

if ! command -v unzip &>/dev/null; then
    MISSING_TOOLS+=("unzip")
fi

# 安装缺失的工具
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}需要安装以下工具: ${MISSING_TOOLS[*]}${NC}"
    echo -e "正在自动安装..."
    
    # 检测包管理器
    if command -v apt-get &>/dev/null; then
        # Debian/Ubuntu
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip wget unzip
    elif command -v yum &>/dev/null; then
        # CentOS/RHEL
        sudo yum install -y python3 python3-pip wget unzip
    elif command -v dnf &>/dev/null; then
        # Fedora
        sudo dnf install -y python3 python3-pip wget unzip
    elif command -v pacman &>/dev/null; then
        # Arch Linux
        sudo pacman -Sy python python-pip wget unzip
    else
        echo -e "${RED}错误: 无法自动安装必要工具${NC}"
        echo -e "请手动安装以下工具后再运行此脚本: ${MISSING_TOOLS[*]}"
        exit 1
    fi
fi

# 再次检查必要工具
for tool in python3 pip3 wget unzip; do
    if ! command -v $tool &>/dev/null; then
        echo -e "${RED}错误: 无法安装 $tool${NC}"
        echo -e "请手动安装后再运行此脚本。"
        exit 1
    fi
done

echo -e "${GREEN}所有必要工具已准备就绪！${NC}"
sleep 1

# 下载项目文件
echo -e "${YELLOW}正在下载项目文件...${NC}"
wget -q -O crypto_monitor.zip "https://github.com/用户名/crypto_monitor/archive/refs/heads/main.zip" || {
    echo -e "${RED}下载失败，尝试备用链接...${NC}"
    # 这里可以添加备用下载链接
    exit 1
}

# 解压文件
echo -e "${YELLOW}正在解压文件...${NC}"
unzip -q crypto_monitor.zip || {
    echo -e "${RED}解压失败${NC}"
    exit 1
}

# 找到解压后的目录
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "crypto_monitor*" | head -n 1)
if [ -z "$EXTRACTED_DIR" ]; then
    echo -e "${RED}找不到解压后的目录${NC}"
    exit 1
fi

# 创建安装目录
INSTALL_DIR="$HOME/crypto_monitor"
echo -e "${YELLOW}正在安装到 $INSTALL_DIR...${NC}"

# 备份现有安装
if [ -d "$INSTALL_DIR" ]; then
    BACKUP_DIR="$INSTALL_DIR.bak.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}发现现有安装，正在备份到 $BACKUP_DIR...${NC}"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
fi

# 移动文件
mkdir -p "$INSTALL_DIR"
cp -r "$EXTRACTED_DIR"/* "$INSTALL_DIR/"

# 安装依赖
echo -e "${YELLOW}正在安装依赖...${NC}"
cd "$INSTALL_DIR"
pip3 install -q -r requirements.txt || {
    echo -e "${RED}安装依赖失败${NC}"
    exit 1
}

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

# 清理临时文件
echo -e "${YELLOW}正在清理临时文件...${NC}"
cd "$HOME"
rm -rf "$TEMP_DIR"

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}               安装成功！                             ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""
echo -e "您可以通过以下方式启动监控系统："
echo -e "1. 双击桌面上的 ${YELLOW}'Crypto Monitor'${NC} 图标"
echo -e "2. 双击主目录中的 ${YELLOW}'启动加密货币监控.sh'${NC} 文件"
echo -e "3. 在终端中运行: ${YELLOW}$INSTALL_DIR/start_monitor.sh${NC}"
echo ""
echo -e "${YELLOW}首次运行时，系统会要求您输入：${NC}"
echo -e "1. Telegram Bot Token (从BotFather获取)"
echo -e "2. Telegram Chat ID (您的群组ID或频道用户名)"
echo ""
echo -e "是否现在启动监控系统？(y/n)"
read -p "> " START_NOW

if [[ "$START_NOW" == "y" || "$START_NOW" == "Y" ]]; then
    echo -e "${GREEN}正在启动监控系统...${NC}"
    "$INSTALL_DIR/start_monitor.sh"
else
    echo -e "${GREEN}安装完成！您可以稍后手动启动监控系统。${NC}"
fi
