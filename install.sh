#!/bin/bash

echo "🚀 开始安装 Gate.io 异动监控系统..."

# 安装 Python3 和 pip（适用于 Debian/Ubuntu/CentOS）
if ! command -v python3 &> /dev/null; then
    echo "🔧 安装 Python3..."
    if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y python3 python3-pip
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y python3 python3-pip
    fi
fi

# 创建虚拟环境（可选）
python3 -m venv venv
source venv/bin/activate

# 安装依赖
echo "📦 安装依赖包..."
pip install --upgrade pip
pip install -r requirements.txt

# 初始化数据库
echo "🗂 初始化数据库..."
python init_db.py

# 确保日志目录存在
mkdir -p logs

# 启动监控程序（后台）
echo "🔍 启动监控程序..."
nohup python monitor.py > logs/monitor_stdout.log 2>&1 &

# 启动 Web 面板
echo "🌐 启动 Web 面板 http://localhost:8080 ..."
nohup uvicorn web_server:app --host 0.0.0.0 --port 8080 > logs/web_stdout.log 2>&1 &

echo "✅ 安装完成！请在浏览器中访问 http://localhost:8080"
