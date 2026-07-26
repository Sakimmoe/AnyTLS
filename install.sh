#!/bin/bash
set -uo pipefail

export DEBIAN_FRONTEND=noninteractive

# 参数与路径设置
ANYTLS_PORT=${1:-26216}
ANYTLS_PASSWORD=${2:-kokonoeyukari}
NET_MODE=${3:-}

INSTALL_PATH="/usr/local/bin/anytls-server"
CONFIG_DIR="/etc/anytls"
CONFIG_FILE="${CONFIG_DIR}/config"
SERVICE_FILE="/etc/systemd/system/anytls.service"
GITHUB_API="https://api.github.com/repos/anytls/anytls-go/releases/latest"

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

check_root(){
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用 root 权限运行${RESET}"
        exit 1
    fi
}

check_arch(){
    case "$(uname -m)" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo "不支持的 CPU 架构"; exit 1 ;;
    esac
}

install_dependencies(){
    echo "📦 检查并安装依赖..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq || true
        apt-get install -y -qq curl wget jq ufw openssl tar unzip >/dev/null 2>&1 || true
    fi
}

network_opt(){
    echo "🌐 开启 BBR 网络优化..."
    cat >/etc/sysctl.d/99-bbr.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl --system >/dev/null 2>&1 || true
}

get_latest(){
    echo "🔎 获取 AnyTLS 最新版本号..."
    VERSION=$(curl -s ${GITHUB_API} | jq -r '.tag_name' 2>/dev/null || true)
    if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
        echo -e "${RED}获取最新版本失败，请检查网络连接${RESET}"
        exit 1
    fi
    echo "最新版本: ${VERSION}"
}

download_anytls(){
    echo "⬇️ 下载 AnyTLS 二进制文件..."
    ASSET_URL=$(curl -s ${GITHUB_API} \
    | jq -r ".assets[].browser_download_url" \
    | grep -i "linux" \
    | grep -i "${ARCH}" \
    | grep -v -i "sha256" \
    | head -1 || true)

    if [ -z "$ASSET_URL" ]; then
        echo -e "${RED}未找到适用于 Linux ${ARCH} 的下载文件${RESET}"
        exit 1
    fi

    TMP=$(mktemp -d)
    wget -q "$ASSET_URL" -O ${TMP}/anytls.pkg

    case "$ASSET_URL" in
        *.tar.gz) tar -xf ${TMP}/anytls.pkg -C ${TMP} ;;
        *.zip) unzip -q ${TMP}/anytls.pkg -d ${TMP} ;;
        *) cp ${TMP}/anytls.pkg ${TMP}/anytls-server ;;
    esac

    FILE=$(find ${TMP} -type f \( -name "anytls-server" -o -name "anytls" \) | head -1 || true)
    if [ -z "$FILE" ]; then
        echo -e "${RED}解压后未找到二进制文件${RESET}"
        rm -rf ${TMP}
        exit 1
    fi

    mkdir -p ${CONFIG_DIR}
    cp "$FILE" ${INSTALL_PATH}
    chmod +x ${INSTALL_PATH}
    rm -rf ${TMP}
}

get_ip(){
    IPV4=$(curl -4 -s --max-time 5 https://api.ipify.org || echo "无")
    IPV6=$(curl -6 -s --connect-timeout 3 https://api64.ipify.org || echo "无")
}

create_service(){
    LISTEN="[::]"
    [ "$NET_MODE" = "4" ] && LISTEN="0.0.0.0"

    cat >${CONFIG_FILE} <<EOF
PORT=${ANYTLS_PORT}
PASSWORD=${ANYTLS_PASSWORD}
LISTEN=${LISTEN}
EOF

    cat >${SERVICE_FILE} <<EOF
[Unit]
Description=AnyTLS Server Service
After=network.target

[Service]
Type=simple
LimitNOFILE=65535
ExecStart=${INSTALL_PATH} -l ${LISTEN}:${ANYTLS_PORT} -p ${ANYTLS_PASSWORD}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable anytls >/dev/null 2>&1
    systemctl restart anytls
}

firewall(){
    echo "🛡️ 配置防火墙放行端口..."
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${ANYTLS_PORT}/tcp >/dev/null 2>&1 || true
        ufw allow ${ANYTLS_PORT}/udp >/dev/null 2>&1 || true
    fi
}

show_info(){
    get_ip
    echo
    echo "=============================="
    echo "       AnyTLS 节点信息        "
    echo "=============================="
    echo "IPv4     : ${IPV4}"
    echo "IPv6     : ${IPV6}"
    echo "Port     : ${ANYTLS_PORT}"
    echo "Password : ${ANYTLS_PASSWORD}"
    echo "------------------------------"
    echo "URI链接  :"
    echo "anytls://${ANYTLS_PASSWORD}@${IPV4}:${ANYTLS_PORT}"
    echo "=============================="
    echo
}

install_anytls(){
    check_root
    check_arch
    install_dependencies
    network_opt
    get_latest
    download_anytls
    create_service
    firewall
    
    sleep 2
    if systemctl is-active --quiet anytls; then
        echo -e "${GREEN}AnyTLS 安装成功并已正常启动！${RESET}"
        show_info
    else
        echo -e "${RED}AnyTLS 启动失败，请检查下方日志：${RESET}"
        journalctl -u anytls -n 30 --no-pager
    fi
}

menu(){
    clear
    echo "=============================="
    echo "    AnyTLS 管理脚本           "
    echo "=============================="
    echo "1. 安装 AnyTLS"
    echo "2. 查看节点信息"
    echo "3. 启动服务"
    echo "4. 停止服务"
    echo "5. 重启服务"
    echo "6. 查看实时日志"
    echo "7. 卸载 AnyTLS"
    echo "0. 退出"
    echo "=============================="
    read -p "请输入选项 [0-7]: " num

    case $num in
        1) install_anytls ;;
        2) show_info ;;
        3) systemctl start anytls && echo "已启动" ;;
        4) systemctl stop anytls && echo "已停止" ;;
        5) systemctl restart anytls && echo "已重启" ;;
        6) journalctl -u anytls -f ;;
        7)
            systemctl stop anytls >/dev/null 2>&1 || true
            systemctl disable anytls >/dev/null 2>&1 || true
            rm -f ${SERVICE_FILE} ${INSTALL_PATH}
            rm -rf ${CONFIG_DIR}
            systemctl daemon-reload
            echo "已成功卸载 AnyTLS"
            ;;
        0) exit 0 ;;
        *) echo "输入无效" ;;
    esac
}

if [ $# -gt 0 ]; then
    install_anytls
else
    menu
fi
