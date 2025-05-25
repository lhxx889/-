#!/bin/bash
# 超级一键下载解压安装脚本 - 终极版
# 一行命令完成下载、解压和安装

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
echo -e "这个脚本会自动为您完成所有下载、解压和安装步骤。"
echo ""

# 安装必要工具
echo -e "${YELLOW}正在安装必要工具...${NC}"
sudo apt-get update -qq
sudo apt-get install -y -qq python3 python3-pip wget unzip

# 创建安装目录
echo -e "${YELLOW}正在创建安装目录...${NC}"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 下载zip文件
echo -e "${YELLOW}正在下载安装包...${NC}"
wget -q https://raw.githubusercontent.com/用户名/仓库名/main/crypto_monitor_final.zip -O crypto_monitor_final.zip

# 检查下载是否成功
if [ ! -f crypto_monitor_final.zip ]; then
    echo -e "${RED}下载失败，请检查网络连接或GitHub仓库地址${NC}"
    exit 1
fi

# 解压文件
echo -e "${YELLOW}正在解压安装包...${NC}"
unzip -o crypto_monitor_final.zip

# 检查解压是否成功
if [ ! -d "src" ]; then
    echo -e "${RED}解压失败，安装包可能损坏${NC}"
    exit 1
fi

# 安装Python依赖
echo -e "${YELLOW}正在安装Python依赖...${NC}"
pip3 install requests

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

# 创建菜单快捷方式
echo -e "${YELLOW}正在创建菜单快捷方式...${NC}"
if [ -d "$HOME/Desktop" ]; then
    cat > "$HOME/Desktop/CryptoMenu.desktop" << EOF
[Desktop Entry]
Name=Crypto Menu
Comment=Gate.io加密货币异动监控系统菜单
Exec=gnome-terminal -- bash -c "cd $INSTALL_DIR && python3 standalone_menu.py; exec bash"
Terminal=true
Type=Application
Icon=utilities-terminal
EOF
    chmod +x "$HOME/Desktop/CryptoMenu.desktop"
fi

cat > "$HOME/打开交互菜单.sh" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
python3 standalone_menu.py
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
echo -e "您可以通过以下方式打开交互菜单："
echo -e "1. 双击桌面上的 ${YELLOW}'Crypto Menu'${NC} 图标"
echo -e "2. 双击主目录中的 ${YELLOW}'打开交互菜单.sh'${NC} 文件"
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
