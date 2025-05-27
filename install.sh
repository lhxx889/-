#!/bin/bash

# Gate加密货币监控脚本一键安装脚本
# 适用于Linux系统

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

# 检查是否为root用户
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_warning "当前以root用户运行，建议使用普通用户运行此脚本"
        read -p "是否继续? (y/n): " choice
        case "$choice" in 
            y|Y ) return 0;;
            * ) return 1;;
        esac
    fi
    return 0
}

# 检查系统环境
check_system() {
    print_info "检查系统环境..."
    
    # 检查是否为Linux系统
    if [ "$(uname)" != "Linux" ]; then
        print_error "此脚本仅支持Linux系统"
        exit 1
    fi
    
    # 检查发行版
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        print_info "检测到操作系统: $OS"
    else
        OS="Unknown"
        print_warning "无法确定操作系统类型，将尝试继续安装"
    fi
    
    print_success "系统环境检查完成"
}

# 检查并安装必要的系统依赖
install_system_dependencies() {
    print_info "安装系统依赖..."
    
    # 检查包管理器
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        print_info "使用apt-get安装依赖"
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip python3-venv git
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        print_info "使用yum安装依赖"
        sudo yum update -y
        sudo yum install -y python3 python3-pip git
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        print_info "使用dnf安装依赖"
        sudo dnf update -y
        sudo dnf install -y python3 python3-pip python3-virtualenv git
    else
        print_error "不支持的包管理器，请手动安装Python 3和pip"
        exit 1
    fi
    
    print_success "系统依赖安装完成"
}

# 检查Python版本
check_python() {
    print_info "检查Python版本..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d " " -f 2)
        print_info "检测到Python版本: $PYTHON_VERSION"
        
        # 检查Python版本是否>=3.6
        PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
        PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
        
        if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 6 ]); then
            print_error "Python版本必须>=3.6，请升级Python"
            exit 1
        fi
    else
        print_error "未检测到Python 3，请安装Python 3.6或更高版本"
        exit 1
    fi
    
    print_success "Python版本检查通过"
}

# 创建虚拟环境
create_virtualenv() {
    print_info "创建Python虚拟环境..."
    
    # 检查项目目录
    if [ ! -d "gate_crypto_monitor" ]; then
        print_error "未找到项目目录，请确保在正确的目录中运行此脚本"
        exit 1
    fi
    
    # 创建虚拟环境
    cd gate_crypto_monitor
    python3 -m venv venv
    
    if [ ! -d "venv" ]; then
        print_error "创建虚拟环境失败"
        exit 1
    fi
    
    print_success "虚拟环境创建成功"
}

# 安装Python依赖
install_python_dependencies() {
    print_info "安装Python依赖..."
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 创建requirements.txt文件
    cat > requirements.txt << EOF
requests>=2.25.1
pandas>=1.2.0
pyyaml>=5.4.1
schedule>=1.1.0
python-telegram-bot>=13.7
beautifulsoup4>=4.9.3
lxml>=4.6.3
pytz>=2021.1
EOF
    
    # 安装依赖
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # 检查安装结果
    if [ $? -ne 0 ]; then
        print_error "安装Python依赖失败"
        exit 1
    fi
    
    print_success "Python依赖安装完成"
}

# 创建默认配置文件
create_default_config() {
    print_info "创建默认配置文件..."
    
    # 创建配置文件
    cat > config.yaml << EOF
# Gate加密货币监控脚本配置文件

# 监控设置
monitoring:
  interval: 60  # 监控间隔（秒）
  threshold:
    min: 30  # 最小涨跌幅阈值（%）
    max: 50  # 最大涨跌幅阈值（%）
  coins: []  # 空列表表示监控所有币种，否则只监控指定币种

# 推送设置
notification:
  telegram:
    enabled: true
    bot_token: ""  # Telegram Bot Token
    chat_id: ""    # Telegram Chat ID
  email:
    enabled: true
    smtp_server: ""  # SMTP服务器
    smtp_port: 587   # SMTP端口
    username: ""     # 邮箱用户名
    password: ""     # 邮箱密码
    recipients: []   # 接收邮件的邮箱列表

# 数据存储设置
storage:
  data_dir: "./data"  # 数据存储目录
  log_dir: "./logs"   # 日志存储目录
EOF
    
    print_success "默认配置文件创建完成"
}

# 创建启动脚本
create_startup_script() {
    print_info "创建启动脚本..."
    
    # 创建启动脚本
    cat > start.sh << 'EOF'
#!/bin/bash

# 激活虚拟环境
source venv/bin/activate

# 启动监控脚本
python main.py "$@"
EOF
    
    # 添加执行权限
    chmod +x start.sh
    
    print_success "启动脚本创建完成"
}

# 创建模块初始化文件
create_module_init() {
    print_info "创建模块初始化文件..."
    
    # 创建modules/__init__.py
    mkdir -p modules
    touch modules/__init__.py
    
    # 创建utils/__init__.py
    mkdir -p utils
    touch utils/__init__.py
    
    print_success "模块初始化文件创建完成"
}

# 创建主程序入口
create_main_script() {
    print_info "创建主程序入口..."
    
    # 创建main.py
    cat > main.py << 'EOF'
#!/usr/bin/env python3
"""
Gate加密货币监控脚本主程序
"""
import os
import sys
import time
import logging
import argparse
import yaml
from datetime import datetime

# 确保目录结构存在
os.makedirs('data', exist_ok=True)
os.makedirs('logs', exist_ok=True)

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("logs/main.log"),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("main")

# 导入模块
try:
    from modules.data_collector import DataCollector
    from modules.info_scraper import InfoScraper
    from modules.analyzer import PriceAnalyzer
    from modules.notifier import Notifier
    from modules.controller import Controller
except ImportError as e:
    logger.error(f"导入模块失败: {e}")
    logger.error("请确保已安装所有依赖")
    sys.exit(1)

def monitor_once(min_threshold=30.0, max_threshold=50.0, coins=None):
    """
    执行一次完整的监控流程
    
    Args:
        min_threshold: 最小涨跌幅阈值（百分比）
        max_threshold: 最大涨跌幅阈值（百分比）
        coins: 监控的币种列表，None表示监控所有币种
    """
    logger.info(f"开始执行监控，阈值 {min_threshold}%-{max_threshold}%")
    
    try:
        # 1. 收集价格数据
        collector = DataCollector()
        alerts = collector.monitor_price_changes(
            interval=0,  # 不等待，立即返回
            min_threshold=min_threshold,
            max_threshold=max_threshold
        )
        
        if not alerts:
            logger.info("未发现符合条件的币种")
            return
        
        logger.info(f"发现 {len(alerts)} 个符合条件的币种")
        
        # 过滤指定币种
        if coins:
            filtered_alerts = []
            for alert in alerts:
                currency_pair = alert.get('currency_pair', '')
                base_currency = currency_pair.split('_')[0]
                if base_currency in coins or currency_pair in coins:
                    filtered_alerts.append(alert)
            
            alerts = filtered_alerts
            logger.info(f"过滤后剩余 {len(alerts)} 个币种")
        
        # 2. 获取币种信息
        scraper = InfoScraper()
        coin_infos = {}
        
        for alert in alerts:
            currency_pair = alert.get('currency_pair', '')
            coin_info = scraper.get_coin_full_info(currency_pair)
            coin_infos[currency_pair] = coin_info
        
        # 3. 分析价格变化原因
        analyzer = PriceAnalyzer()
        analyses = analyzer.batch_analyze(alerts, coin_infos)
        
        # 4. 发送通知
        notifier = Notifier()
        sent_count = notifier.batch_send(analyses)
        
        logger.info(f"监控完成，发送了 {sent_count} 条通知")
    except Exception as e:
        logger.error(f"监控过程中发生错误: {e}")

def monitor_loop(interval=60, min_threshold=30.0, max_threshold=50.0, coins=None):
    """
    持续监控循环
    
    Args:
        interval: 监控间隔（秒）
        min_threshold: 最小涨跌幅阈值（百分比）
        max_threshold: 最大涨跌幅阈值（百分比）
        coins: 监控的币种列表，None表示监控所有币种
    """
    logger.info(f"开始持续监控，间隔 {interval} 秒，阈值 {min_threshold}%-{max_threshold}%")
    
    while True:
        start_time = time.time()
        
        try:
            monitor_once(min_threshold, max_threshold, coins)
        except Exception as e:
            logger.error(f"监控过程中发生错误: {e}")
        
        # 计算等待时间
        elapsed = time.time() - start_time
        wait_time = max(0, interval - elapsed)
        
        if wait_time > 0:
            logger.info(f"等待 {wait_time:.1f} 秒后进行下一次监控")
            time.sleep(wait_time)

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='Gate加密货币监控脚本')
    
    # 命令行参数
    parser.add_argument('--start', action='store_true', help='启动监控')
    parser.add_argument('--stop', action='store_true', help='停止监控')
    parser.add_argument('--status', action='store_true', help='查看监控状态')
    parser.add_argument('--test', action='store_true', help='测试推送功能')
    parser.add_argument('--once', action='store_true', help='执行一次监控')
    parser.add_argument('--min', type=float, help='设置最小涨跌幅阈值（百分比）')
    parser.add_argument('--max', type=float, help='设置最大涨跌幅阈值（百分比）')
    parser.add_argument('--interval', type=int, help='设置监控间隔（秒）')
    parser.add_argument('--coins', type=str, help='设置监控币种，多个币种用逗号分隔')
    
    args = parser.parse_args()
    
    # 创建控制器
    controller = Controller()
    
    # 处理命令行参数
    if args.min is not None or args.max is not None:
        min_threshold = args.min if args.min is not None else controller.config.get('monitoring', {}).get('threshold', {}).get('min', 30)
        max_threshold = args.max if args.max is not None else controller.config.get('monitoring', {}).get('threshold', {}).get('max', 50)
        controller.set_threshold(min_threshold, max_threshold)
    
    if args.interval is not None:
        controller.set_interval(args.interval)
    
    if args.coins is not None:
        coins = [coin.strip() for coin in args.coins.split(',') if coin.strip()]
        controller.set_coins(coins)
    
    if args.test:
        results = controller.test_notification()
        for channel, success in results.items():
            status = "成功" if success else "失败"
            print(f"{channel} 推送测试: {status}")
    
    if args.status:
        status = controller.get_status()
        print(f"监控状态: {'运行中' if status['running'] else '已停止'}")
        print(f"配置信息:")
        print(f"  监控间隔: {status['config'].get('monitoring', {}).get('interval', 60)} 秒")
        print(f"  涨跌幅阈值: {status['config'].get('monitoring', {}).get('threshold', {}).get('min', 30)}% - {status['config'].get('monitoring', {}).get('threshold', {}).get('max', 50)}%")
        coins = status['config'].get('monitoring', {}).get('coins', [])
        print(f"  监控币种: {', '.join(coins) if coins else '所有币种'}")
        print(f"  Telegram推送: {'启用' if status['config'].get('notification', {}).get('telegram', {}).get('enabled', False) else '禁用'}")
        print(f"  邮件推送: {'启用' if status['config'].get('notification', {}).get('email', {}).get('enabled', False) else '禁用'}")
    
    if args.stop:
        if controller.stop_monitoring():
            print("监控已停止")
        else:
            print("监控未在运行")
    
    if args.once:
        print("执行一次监控...")
        config = controller.config
        min_threshold = config.get('monitoring', {}).get('threshold', {}).get('min', 30)
        max_threshold = config.get('monitoring', {}).get('threshold', {}).get('max', 50)
        coins = config.get('monitoring', {}).get('coins', [])
        monitor_once(min_threshold, max_threshold, coins if coins else None)
        print("监控执行完成")
    
    if args.start:
        if not controller.is_monitoring():
            config = controller.config
            interval = config.get('monitoring', {}).get('interval', 60)
            min_threshold = config.get('monitoring', {}).get('threshold', {}).get('min', 30)
            max_threshold = config.get('monitoring', {}).get('threshold', {}).get('max', 50)
            coins = config.get('monitoring', {}).get('coins', [])
            
            print(f"启动监控，间隔 {interval} 秒，阈值 {min_threshold}%-{max_threshold}%")
            
            # 定义监控函数
            def monitor_wrapper(interval, min_threshold, max_threshold, coins):
                monitor_once(min_threshold, max_threshold, coins if coins else None)
            
            controller.start_monitoring(monitor_wrapper)
            
            # 如果没有其他参数，则阻塞主线程
            if not (args.test or args.status or args.stop or args.once):
                try:
                    while controller.is_monitoring():
                        time.sleep(1)
                except KeyboardInterrupt:
                    print("\n接收到中断信号，停止监控...")
                    controller.stop_monitoring()
        else:
            print("监控已在运行中")
    
    # 如果没有任何参数，显示帮助信息
    if not any(vars(args).values()):
        parser.print_help()

if __name__ == "__main__":
    main()
EOF
    
    # 添加执行权限
    chmod +x main.py
    
    print_success "主程序入口创建完成"
}

# 创建必要的目录
create_directories() {
    print_info "创建必要的目录..."
    
    mkdir -p data logs
    
    print_success "目录创建完成"
}

# 显示使用说明
show_usage() {
    echo
    echo -e "${GREEN}=== Gate加密货币监控脚本安装完成 ===${NC}"
    echo
    echo -e "使用方法:"
    echo -e "  ${BLUE}./start.sh --start${NC}        启动监控"
    echo -e "  ${BLUE}./start.sh --stop${NC}         停止监控"
    echo -e "  ${BLUE}./start.sh --status${NC}       查看监控状态"
    echo -e "  ${BLUE}./start.sh --test${NC}         测试推送功能"
    echo -e "  ${BLUE}./start.sh --once${NC}         执行一次监控"
    echo -e "  ${BLUE}./start.sh --min 30${NC}       设置最小涨跌幅阈值（百分比）"
    echo -e "  ${BLUE}./start.sh --max 50${NC}       设置最大涨跌幅阈值（百分比）"
    echo -e "  ${BLUE}./start.sh --interval 60${NC}  设置监控间隔（秒）"
    echo -e "  ${BLUE}./start.sh --coins BTC,ETH${NC} 设置监控币种（逗号分隔）"
    echo
    echo -e "在使用前，请先编辑${YELLOW}config.yaml${NC}文件，配置Telegram和邮箱推送信息。"
    echo
}

# 主函数
main() {
    echo -e "${GREEN}=== Gate加密货币监控脚本安装程序 ===${NC}"
    echo
    
    # 检查是否为root用户
    check_root || exit 1
    
    # 检查系统环境
    check_system
    
    # 安装系统依赖
    install_system_dependencies
    
    # 检查Python版本
    check_python
    
    # 创建虚拟环境
    create_virtualenv
    
    # 安装Python依赖
    install_python_dependencies
    
    # 创建默认配置文件
    create_default_config
    
    # 创建启动脚本
    create_startup_script
    
    # 创建模块初始化文件
    create_module_init
    
    # 创建主程序入口
    create_main_script
    
    # 创建必要的目录
    create_directories
    
    # 显示使用说明
    show_usage
}

# 执行主函数
main
