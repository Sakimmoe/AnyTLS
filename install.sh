#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ==========================================
# AnyTLS-go 一键安装管理脚本
# ==========================================


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



# ==========================================
# root检测
# ==========================================

check_root(){

if [ "$EUID" -ne 0 ]; then

echo -e "${RED}请使用root运行${RESET}"

exit 1

fi

}




# ==========================================
# 架构
# ==========================================

check_arch(){

case "$(uname -m)" in

x86_64|amd64)

ARCH="amd64"

;;

aarch64|arm64)

ARCH="arm64"

;;

*)

echo "不支持架构"

exit 1

;;

esac

}




# ==========================================
# 依赖
# ==========================================

install_dependencies(){

echo "📦 安装依赖"


apt-get update -qq || true


apt-get install -y -qq \
curl \
wget \
jq \
ufw \
openssl \
cron \
iproute2 \
ca-certificates \
tar \
unzip \
>/dev/null 2>&1 || true


}




# ==========================================
# 网络优化
# ==========================================


network_opt(){


echo "🌐 网络优化"


grep -q "precedence ::ffff:0:0/96 100" /etc/gai.conf 2>/dev/null \
|| echo "precedence ::ffff:0:0/96 100" >> /etc/gai.conf



cat >/etc/sysctl.d/99-bbr.conf <<EOF

net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

EOF


sysctl --system >/dev/null 2>&1 || true



systemctl disable systemd-resolved --now 2>/dev/null || true


rm -f /etc/resolv.conf


cat >/etc/resolv.conf <<EOF

nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 2606:4700:4700::1111

EOF


chattr +i /etc/resolv.conf 2>/dev/null || true


}




# ==========================================
# 获取最新版
# ==========================================


get_latest(){

echo "🔎 获取AnyTLS最新版"


VERSION=$(curl -s ${GITHUB_API} | jq -r '.tag_name')


if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then

echo "获取版本失败"

exit 1

fi


echo "版本: ${VERSION}"


}




# ==========================================
# 下载
# ==========================================


download_anytls(){


echo "⬇️ 下载 AnyTLS"


ASSET_URL=$(curl -s ${GITHUB_API} \
| jq -r ".assets[].browser_download_url" \
| grep "${ARCH}" \
| head -1)



if [ -z "$ASSET_URL" ]; then

echo -e "${RED}找不到下载文件${RESET}"

exit 1

fi



TMP=$(mktemp -d)



wget -q "$ASSET_URL" -O ${TMP}/anytls.pkg



case "$ASSET_URL" in


*.tar.gz)

tar -xf ${TMP}/anytls.pkg -C ${TMP}

;;


*.zip)

unzip -q ${TMP}/anytls.pkg -d ${TMP}

;;


*)

cp ${TMP}/anytls.pkg ${TMP}/anytls-server

;;

esac



FILE=$(find ${TMP} -name "anytls-server" | head -1)



if [ -z "$FILE" ]; then

echo "未找到二进制文件"

exit 1

fi



mkdir -p ${CONFIG_DIR}


cp "$FILE" ${INSTALL_PATH}


chmod +x ${INSTALL_PATH}



rm -rf ${TMP}


}




# ==========================================
# IP
# ==========================================

get_ip(){


IPV4=$(curl -4 -s --max-time 5 https://api.ipify.org || echo 无)


IPV6=$(curl -6 -s --connect-timeout 3 https://api64.ipify.org || echo 无)


}




# ==========================================
# 配置
# ==========================================


create_service(){


if [ "$NET_MODE" = "4" ]; then

LISTEN="0.0.0.0"

else

LISTEN="[::]"

fi



cat >${CONFIG_FILE} <<EOF

PORT=${ANYTLS_PORT}

PASSWORD=${ANYTLS_PASSWORD}

LISTEN=${LISTEN}

EOF




cat >${SERVICE_FILE} <<EOF

[Unit]

Description=AnyTLS Server

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




# ==========================================
# 防火墙
# ==========================================


firewall(){


echo "🛡️ 配置防火墙"



ufw --force reset >/dev/null 2>&1 || true


ufw default deny incoming >/dev/null 2>&1


ufw default allow outgoing >/dev/null 2>&1



SSH_PORT=$(grep -Ei '^Port ' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -1)


if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]];then

SSH_PORT=22

fi



ufw allow ${SSH_PORT}/tcp >/dev/null 2>&1

ufw allow ${ANYTLS_PORT}/tcp >/dev/null 2>&1

ufw allow ${ANYTLS_PORT}/udp >/dev/null 2>&1


ufw --force enable >/dev/null 2>&1


}




# ==========================================
# 清理
# ==========================================


cleanup(){


cat >/etc/cron.d/anytls-clean <<EOF

7 7 * * 0 root apt-get clean && journalctl --vacuum-time=5d --vacuum-size=30M

EOF


}




# ==========================================
# 信息
# ==========================================


show_info(){


get_ip


echo

echo "=============================="

echo " AnyTLS节点信息"

echo "=============================="


echo "IPv4 : ${IPV4}"

echo "IPv6 : ${IPV6}"

echo "Port : ${ANYTLS_PORT}"

echo "Password : ${ANYTLS_PASSWORD}"



echo

echo "URI:"

echo "anytls://${ANYTLS_PASSWORD}@${IPV4}:${ANYTLS_PORT}"

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

cleanup


sleep 2


if systemctl is-active --quiet anytls;then

echo -e "${GREEN}AnyTLS安装成功${RESET}"

show_info


else

echo "启动失败"

journalctl -u anytls -n 30 --no-pager

fi


}





# ==========================================
# 管理
# ==========================================


menu(){


clear


echo "=============================="

echo " AnyTLS 管理脚本"

echo "=============================="

echo "1. 安装 AnyTLS"

echo "2. 查看节点"

echo "3. 启动"

echo "4. 停止"

echo "5. 重启"

echo "6. 日志"

echo "7. 卸载"

echo "0.退出"

echo "=============================="


read -p "选择:" num



case $num in

1) install_anytls ;;

2) show_info ;;

3) systemctl start anytls ;;

4) systemctl stop anytls ;;

5) systemctl restart anytls ;;

6) journalctl -u anytls -f ;;

7)

systemctl stop anytls || true

systemctl disable anytls || true

rm -f ${SERVICE_FILE}

rm -f ${INSTALL_PATH}

rm -rf ${CONFIG_DIR}

systemctl daemon-reload

echo "卸载完成"

;;

0)

exit 0

;;

*)

echo "错误"

;;

esac


}




# ==========================================
# 主入口
# ==========================================


if [ $# -gt 0 ];then

install_anytls

else

menu

fi
