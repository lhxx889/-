#!/bin/bash

set -e

PROJECT_DIR=$(pwd)

检查并安装 pip3

if ! command -v pip3 &> /dev/null; then echo "🔍 未检测到 pip3，正在尝试安装..." if [ -f /etc/debian_version ]; then apt update && apt install -y python3-pip elif [ -f /etc/redhat-release ]; then yum install -y python3-pip else echo "❌ 无法自动安装 pip3，请手动安装后重试。" && exit 1 fi fi

echo "📦 [1/5] 正在安装 Python 依赖..." pip3 install -r requirements.txt

echo "🗃 [2/5] 正在初始化数据库..." python3 src/init_db.py || echo "跳过初始化，可能已经存在。"

echo "🔒 [3/5] 创建日志与数据目录..." mkdir -p logs data

cat <<EOF > gateio-monitor.service [Unit] Description=Gate.io Monitor Service After=network.target

[Service] WorkingDirectory=$PROJECT_DIR ExecStart=/usr/bin/gunicorn -c gunicorn_config.py web.app:app Restart=always User=www-data Group=www-data

[Install] WantedBy=multi-user.target EOF

cat <<EOF > gunicorn_config.py bind = '0.0.0.0:8000' workers = 3 timeout = 120 loglevel = 'info' accesslog = 'logs/access.log' errorlog = 'logs/error.log' EOF

cat <<EOF > nginx.conf server { listen 80; server_name your-domain.com;

location / {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

} EOF

cat <<EOF > README.md

Gate.io 异动监控系统

📦 安装步骤

bash install.sh

🖥 功能概览

实时监控币种价格波动

支持筛选 + 自动刷新图表

Telegram 通知配置

WebSocket 实时日志


📂 项目结构说明

web/：前端页面 + Flask API

src/：主监控逻辑 + 通知发送

data/：SQLite 数据库存储

logs/：运行日志（含 monitor.log）


🔧 部署建议

1. Systemd 守护进程



sudo cp gateio-monitor.service /etc/systemd/system/
sudo systemctl daemon-reexec
sudo systemctl enable gateio-monitor
sudo systemctl start gateio-monitor

2. Nginx 配置参考（已生成 nginx.conf）



🧪 本地调试

bash run_web.sh

默认监听 http://localhost:8000

🤖 Telegram 设置

在前端设置 Telegram Token 与 Chat ID，即可接收通知。

❓ 常见问题

Web 页面打不开？检查端口/防火墙/Nginx 配置

无法收到通知？确认 token 与 chat_id 是否正确


📷 示例截图

（你可以补充界面截图）

EOF

echo "📚 [5/5] 已生成部署配置与说明文档。" echo "✅ 安装完成！请访问 http://localhost:8000 查看系统。"
