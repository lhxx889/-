#!/bin/bash

# bash fonts colors
red=\'\\e[31m\'
yellow=\'\\e[33m\'
gray=\'\\e[90m\'
green=\'\\e[92m\'
blue=\'\\e[94m\'
magenta=\'\\e[95m\'
none=\'\\e[0m\'

_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\\e[41m$@${none}"; }

is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)

err() {
    echo -e "\\n$is_err $@\\n" && exit 1
}

warn() {
    echo -e "\\n$is_warn $@\\n"
}

# root
[[ ${EUID} != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

cmd=$(type -P apt-get || type -P yum)
[[ ! ${cmd} ]] && err "此脚本仅支持 ${yellow}Ubuntu or Debian or CentOS${none}."

# systemd
[[ ! $(type -P systemctl) ]] && {
    err "此系统缺少 ${yellow}systemctl${none}, 请尝试执行:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none}来修复此错误."
}

# x64
case $(uname -m) in
    amd64 | x86_64)
        is_arch=amd64
    ;;
    *aarch64* | *armv8*)
        is_arch=arm64
    ;;
    *)
        err "此脚本仅支持 64 位系统..."
    ;;
esac

is_core=sing-box

# Function to install sing-box
install_singbox() {
    _blue "正在安装 sing-box..."
    # install wget
    if [[ ! $(type -P wget) ]]; then
        ${cmd} install -y wget
    fi

    # install jq
    if [[ ! $(type -P jq) ]]; then
        ${cmd} install -y jq
    fi

    # download sing-box
    if [[ ! -d /etc/${is_core} ]]; then
        mkdir -p /etc/${is_core}
    fi

    # get latest version
    local latest_version=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r ".tag_name | sub(\"^v\"; \"\")")
    if [[ ! ${latest_version} ]]; then
        err "获取 sing-box 最新版本失败, 请检查网络."
    fi

    # download sing-box core
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${is_arch}.tar.gz"
    wget --no-check-certificate -O /tmp/${is_core}.tar.gz ${download_url}
    if [[ $? != 0 ]]; then
        err "下载 sing-box 失败, 请检查网络."
    fi

    # install sing-box core
    tar -zxvf /tmp/${is_core}.tar.gz -C /tmp
    mv /tmp/sing-box-${latest_version}-linux-${is_arch}/sing-box /usr/local/bin/${is_core}
    chmod +x /usr/local/bin/${is_core}
    rm -rf /tmp/${is_core}.tar.gz /tmp/sing-box-${latest_version}-linux-${is_arch}

    # create service
    cat > /etc/systemd/system/${is_core}.service << EOF
[Unit]
Description=${is_core} Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/${is_core} run -c /etc/${is_core}/config.json
Restart=on-failure
RestartPreventExitStatus=1

[Install]
WantedBy=multi-user.target
EOF

    # start service
    systemctl daemon-reload
    systemctl enable ${is_core}
    systemctl start ${is_core}

    _green "${is_core} 安装成功!"
}

# Function to get current configuration
status() {
    _blue "正在获取当前 sing-box 配置..."
    if [[ -f /etc/${is_core}/config.json ]]; then
        cat /etc/${is_core}/config.json | jq .
    else
        _yellow "sing-box 配置文件不存在。请先运行安装或配置命令。"
    fi
}

# Function to update sing-box core
update() {
    _blue "正在更新 sing-box 核心..."
    # get latest version
    local latest_version=$(wget -qO- "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r ".tag_name | sub(\"^v\"; \"\")")
    if [[ ! ${latest_version} ]]; then
        err "获取 sing-box 最新版本失败, 请检查网络."
    fi

    # download sing-box core
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${latest_version}/sing-box-${latest_version}-linux-${is_arch}.tar.gz"
    wget --no-check-certificate -O /tmp/${is_core}.tar.gz ${download_url}
    if [[ $? != 0 ]]; then
        err "下载 sing-box 失败, 请检查网络."
    fi

    # install sing-box core
    tar -zxvf /tmp/${is_core}.tar.gz -C /tmp
    mv /tmp/sing-box-${latest_version}-linux-${is_arch}/sing-box /usr/local/bin/${is_core}
    chmod +x /usr/local/bin/${is_core}
    rm -rf /tmp/${is_core}.tar.gz /tmp/sing-box-${latest_version}-linux-${is_arch}

    # restart service
    systemctl restart ${is_core}

    _green "${is_core} 更新成功!"
}

# Function to uninstall sing-box
uninstall() {
    _blue "正在卸载 sing-box..."
    systemctl stop ${is_core}
    systemctl disable ${is_core}
    rm -rf /usr/local/bin/${is_core} /etc/${is_core} /etc/systemd/system/${is_core}.service
    _green "${is_core} 卸载成功!"
}

# Function to set configuration
set_config() {
    local protocol=$1
    local param=$2
    local value=$3

    if [[ ! -f /etc/${is_core}/config.json ]]; then
        err "sing-box 配置文件不存在。请先运行安装或配置命令。"
    fi

    local config_path="/etc/${is_core}/config.json"

    case "${protocol}" in
        vless-reality)
            if [[ "${param}" == "port" ]]; then
                jq ".inbounds[] |= if .tag == \"vless-in\" then .listen_port = ${value} else . end" ${config_path} > /tmp/config.json && mv /tmp/config.json ${config_path}
                _green "VLESS-Reality 端口已更新为 ${value}"
            else
                _red "不支持的 VLESS-Reality 参数: ${param}"
            fi
            ;;
        socks5)
            if [[ "${param}" == "port" ]]; then
                jq ".inbounds[] |= if .tag == \"socks-in\" then .listen_port = ${value} else . end" ${config_path} > /tmp/config.json && mv /tmp/config.json ${config_path}
                _green "SOCKS5 端口已更新为 ${value}"
            else
                _red "不支持的 SOCKS5 参数: ${param}"
            fi
            ;;
        hysteria2)
            if [[ "${param}" == "port" ]]; then
                jq ".inbounds[] |= if .tag == \"hysteria2-in\" then .listen_port = ${value} else . end" ${config_path} > /tmp/config.json && mv /tmp/config.json ${config_path}
                _green "Hysteria2 端口已更新为 ${value}"
            elif [[ "${param}" == "password" ]]; then
                jq ".inbounds[] |= if .tag == \"hysteria2-in\" then .users[0].password = \"${value}\" else . end" ${config_path} > /tmp/config.json && mv /tmp/config.json ${config_path}
                _green "Hysteria2 密码已更新"
            else
                _red "不支持的 Hysteria2 参数: ${param}"
            fi
            ;;
        *)
            _red "不支持的协议: ${protocol}"
            ;;
esac

    systemctl restart ${is_core}
    _green "sing-box 服务已重启。"
}

# Function to create initial configuration
initial_config() {
    _blue "正在创建 sing-box 初始配置..."
    # Check and install wget and jq
    if [[ ! $(type -P wget) ]]; then
        ${cmd} install -y wget
    fi
    if [[ ! $(type -P jq) ]]; then
        ${cmd} install -y jq
    fi

    # Check if sing-box is installed, if not, install it
    if [[ ! -f /usr/local/bin/${is_core} ]]; then
        install_singbox
    fi

    # get ip
    local ip=$(curl -s ifconfig.me/ip)
    if [[ ! ${ip} ]]; then
        err "获取 IP 失败, 请检查网络."
    fi

    # get domain
    local domain=$(read -p "请输入域名: " domain && echo ${domain})
    if [[ ! ${domain} ]]; then
        err "域名不能为空."
    fi

    # get vless port
    local vless_port=$(read -p "请输入 VLESS-Reality 端口(默认 443): " vless_port && echo ${vless_port:-443})
    if [[ ! ${vless_port} ]]; then
        err "VLESS-Reality 端口不能为空."
    fi

    # get socks5 port
    local socks5_port=$(read -p "请输入 SOCKS5 端口(默认 1080): " socks5_port && echo ${socks5_port:-1080})
    if [[ ! ${socks5_port} ]]; then
        err "SOCKS5 端口不能为空."
    fi

    # get hysteria2 port
    local hysteria2_port=$(read -p "请输入 Hysteria2 端口(默认 443): " hysteria2_port && echo ${hysteria2_port:-443})
    if [[ ! ${hysteria2_port} ]]; then
        err "Hysteria2 端口不能为空."
    fi

    # get hysteria2 password
    local hysteria2_password=$(read -p "请输入 Hysteria2 密码(留空则随机生成): " hysteria2_password)
    if [[ -z "${hysteria2_password}" ]]; then
        hysteria2_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
        _yellow "Hysteria2 密码已随机生成: ${hysteria2_password}"
    fi

    # get uuid
    local uuid=$(/usr/local/bin/${is_core} generate uuid)
    if [[ ! ${uuid} ]]; then
        err "生成 UUID 失败."
    fi

    # generate reality keypair once
    local reality_keypair=$(/usr/local/bin/${is_core} generate reality-keypair)
    local private_key=$(echo "${reality_keypair}" | grep -oP "PrivateKey: \K[a-zA-Z0-9]+")
    local public_key=$(echo "${reality_keypair}" | grep -oP "PublicKey: \K[a-zA-Z0-9]+")

    if [[ -z "${private_key}" ]]; then
        err "生成 private key 失败."
    fi

    if [[ -z "${public_key}" ]]; then
        err "生成 public key 失败."
    fi

    # get short id
    local short_id=$(/usr/local/bin/${is_core} generate rand --hex 8)
    if [[ ! ${short_id} ]]; then
        err "生成 short id 失败."
    fi

    # get dest
    local dest=$(read -p "请输入回落地址(默认 www.google.com:443): " dest && echo ${dest:-www.google.com:443})
    if [[ ! ${dest} ]]; then
        err "回落地址不能为空."
    fi

    # create config directory if not exists
    if [[ ! -d /etc/${is_core} ]]; then
        mkdir -p /etc/${is_core}
    fi

    # create config
    cat > /etc/${is_core}/config.json << EOF
{
    "log": {
        "level": "info"
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "0.0.0.0",
            "listen_port": ${vless_port},
            "sniff": true,
            "sniff_override_destination": true,
            "users": [
                {
                    "uuid": "${uuid}",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "private_key": "${private_key}",
                "reality": {
                    "enabled": true,
                    "handshake_server": "${dest}",
                    "handshake_port": 443,
                    "short_id": [
                        "${short_id}"
                    ]
                }
            }
        },
        {
            "type": "socks",
            "tag": "socks-in",
            "listen": "0.0.0.0",
            "listen_port": ${socks5_port}
        },
        {
            "type": "hysteria2",
            "tag": "hysteria2-in",
            "listen": "0.0.0.0",
            "listen_port": ${hysteria2_port},
            "users": [
                {
                    "password": "${hysteria2_password}"
                }
            ],
            "tls": {
                "enabled": true,
                "private_key": "${private_key}",
                "reality": {
                    "enabled": true,
                    "handshake_server": "${dest}",
                    "handshake_port": 443,
                    "short_id": [
                        "${short_id}"
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ]
}
EOF

    # start service
    systemctl daemon-reload
    systemctl enable ${is_core}
    systemctl start ${is_core}

    _green "${is_core} 配置成功!"

    # show config
    _blue "VLESS-Reality 配置:"
    _cyan "地址: ${ip}"
    _cyan "端口: ${vless_port}"
    _cyan "UUID: ${uuid}"
    _cyan "Public Key: ${public_key}"
    _cyan "Short ID: ${short_id}"
    _cyan "回落地址: ${dest}"

    _blue "SOCKS5 配置:"
    _cyan "地址: ${ip}"
    _cyan "端口: ${socks5_port}"

    _blue "Hysteria2 配置:"
    _cyan "地址: ${ip}"
    _cyan "端口: ${hysteria2_port}"
    _cyan "密码: ${hysteria2_password}"
}

# Main case statement for commands
case "$1" in
    status)
        status
        ;;
    update)
        update
        ;;
    uninstall)
        uninstall
        ;;
    set)
        if [[ -z "$2" || -z "$3" || -z "$4" ]]; then
            echo "Usage: $0 set {vless-reality|socks5|hysteria2} {port|password} <value>"
        else
            set_config "$2" "$3" "$4"
        fi
        ;;
    initial-config)
        initial_config
        ;;
    install)
        install_singbox
        ;;
    *)
        echo "Usage: $0 {status|update|uninstall|set|initial-config|install}"
        ;;
esac


