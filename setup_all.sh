#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 激活虚拟环境
source venv/bin/activate

# 设置VLESS代理
setup_vless() {
    print_info "开始设置VLESS代理..."
    
    # 获取VLESS URI
    read -p "请输入VLESS URI: " vless_uri
    
    if [ -z "$vless_uri" ]; then
        print_error "VLESS URI不能为空"
        return 1
    fi
    
    # 运行VLESS设置脚本
    sudo python3 setup_vless_telegram.py --vless "$vless_uri"
    
    if [ $? -eq 0 ]; then
        print_success "VLESS代理设置完成"
    else
        print_error "VLESS代理设置失败"
        return 1
    fi
}

# 设置Telegram Bot
setup_telegram() {
    print_info "开始设置Telegram Bot..."
    
    # 获取Bot Token和Chat ID
    read -p "请输入Telegram Bot Token: " bot_token
    read -p "请输入Telegram Chat ID: " chat_id
    
    if [ -z "$bot_token" ] || [ -z "$chat_id" ]; then
        print_error "Bot Token和Chat ID不能为空"
        return 1
    fi
    
    # 运行Telegram设置脚本
    sudo python3 setup_vless_telegram.py --bot_token "$bot_token" --chat_id "$chat_id"
    
    if [ $? -eq 0 ]; then
        print_success "Telegram Bot设置完成"
    else
        print_error "Telegram Bot设置失败"
        return 1
    fi
}

# 主菜单
main_menu() {
    while true; do
        echo ""
        echo "======================================================"
        echo "      Gate.io 监控系统一键设置                        "
        echo "======================================================"
        echo "1. 设置VLESS代理"
        echo "2. 设置Twitter API"
        echo "3. 设置Telegram Bot"
        echo "4. 全部设置"
        echo "5. 退出"
        echo "======================================================"
        
        read -p "请选择操作 [1-5]: " choice
        
        case $choice in
            1)
                setup_vless
                ;;
            2)
                print_warning "Twitter API设置功能已移除，请使用VLESS和Telegram设置"
                ;;
            3)
                setup_telegram
                ;;
            4)
                setup_vless && setup_telegram
                ;;
            5)
                print_info "退出设置"
                exit 0
                ;;
            *)
                print_error "无效的选择，请重新输入"
                ;;
        esac
    done
}

# 执行主菜单
main_menu
