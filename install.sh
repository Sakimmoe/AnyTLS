#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive


# =========================
# AnyTLS 参数
# =========================

ANYTLS_PORT=${1:-26216}
ANYTLS_PASSWORD=${2:-kokonoeyukari}
NET_MODE=${3:-}

ANYTLS_VERSION="v0.0.12"

INSTALL_DIR="/usr/local/bin"
SERVICE_NAME="anytls"


echo "=========================================="
echo " AnyTLS 部署脚本"
echo "=========================================="


if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 root 用户运行"
    exit 1
fi



# =========================
# 安装依赖
# =========================

echo "📦 安装依赖..."

apt-get update -qq || true

apt-get install -y -qq \
wget \
curl \
ufw \
iproute2 \
cron \
openssl \
tar \
ca-certificates \
2>/dev/null || true



# =========================
# 网络优化
# =========================


echo "🌐 优化网络配置..."


grep -q \
"precedence ::ffff:0:0/96 100" \
/etc/gai.conf 2>/dev/null \
|| echo "precedence ::ffff:0:0/96 100" >> /etc/gai.conf



systemctl disable systemd-resolved --now 2>/dev/null || true

systemctl mask systemd-resolved 2>/dev/null || true



rm -f /etc/resolv.conf


cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 2606:4700:4700::1111
nameserver 2001:4860:4860::8888
EOF


chattr +i /etc/resolv.conf 2>/dev/null || true



cat >/etc/sysctl.d/99-bbr.conf <<EOF

net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

EOF


sysctl --system >/dev/null 2>&1 || true



# =========================
# 获取IP
# =========================


echo "📡 获取服务器IP..."


IPV4=$(curl -4 -s --max-time 5 https://api.ipify.org || echo "无")

IPV6=$(curl -6 -s --connect-timeout 3 https://api64.ipify.org || echo "无")



MAIN_IP=$(
if [ "$IPV4" != "无" ]; then
    echo "$IPV4"
else
    echo "$IPV6"
fi
)



if [ "$NET_MODE" = "4" ]; then

    LISTEN_ADDR="0.0.0.0"

else

    LISTEN_ADDR="[::]"

fi




# =========================
# 架构检测
# =========================


case "$(uname -m)" in

x86_64|amd64)

    ARCH="amd64"
    ;;


aarch64|arm64)

    ARCH="arm64"
    ;;


*)

echo "❌ 不支持架构"

exit 1

;;

esac




# =========================
# 下载 AnyTLS
# =========================


echo "🚀 下载 AnyTLS..."


systemctl stop anytls 2>/dev/null || true



DOWNLOAD_URL="https://github.com/anytls/anytls-go/releases/download/${ANYTLS_VERSION}/anytls-linux-${ARCH}"



wget -q \
-O ${INSTALL_DIR}/anytls-server \
"$DOWNLOAD_URL" \
|| {

echo "❌ AnyTLS 下载失败"

exit 1

}



chmod +x ${INSTALL_DIR}/anytls-server




# =========================
# 端口检测
# =========================


if ss -tlnp | grep -q ":${ANYTLS_PORT} "; then

echo "❌ 端口 ${ANYTLS_PORT} 已被占用"

ss -tlnp | grep ":${ANYTLS_PORT}"

exit 1

fi




# =========================
# systemd
# =========================


echo "⚙️ 创建服务..."


cat >/etc/systemd/system/anytls.service <<EOF

[Unit]

Description=AnyTLS Proxy Service

After=network.target



[Service]

Type=simple

LimitNOFILE=65535

ExecStart=/usr/local/bin/anytls-server -l ${LISTEN_ADDR}:${ANYTLS_PORT} -p ${ANYTLS_PASSWORD}

Restart=always

RestartSec=3



[Install]

WantedBy=multi-user.target

EOF



systemctl daemon-reload


systemctl enable anytls >/dev/null 2>&1 || true


systemctl restart anytls



sleep 2



if ! systemctl is-active --quiet anytls; then

echo "❌ AnyTLS启动失败"

journalctl -u anytls -n 30 --no-pager

exit 1

fi




# =========================
# 防火墙
# =========================


echo "🛡️ 配置UFW..."


ufw --force reset >/dev/null 2>&1 || true


ufw default deny incoming >/dev/null 2>&1 || true

ufw default allow outgoing >/dev/null 2>&1 || true



SSH_PORT=$(grep -Ei '^\s*Port\s+' /etc/ssh/sshd_config 2>/dev/null \
| head -1 \
| awk '{print $2}')



if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]]; then

SSH_PORT=22

fi



ufw allow 22/tcp >/dev/null 2>&1 || true

ufw allow ${SSH_PORT}/tcp >/dev/null 2>&1 || true


ufw allow ${ANYTLS_PORT}/tcp comment "AnyTLS TCP" >/dev/null 2>&1 || true


ufw allow ${ANYTLS_PORT}/udp comment "AnyTLS UDP" >/dev/null 2>&1 || true


ufw --force enable >/dev/null 2>&1 || true


ufw reload >/dev/null 2>&1 || true




# =========================
# 定时清理
# =========================


echo "🧹 添加清理任务..."


cat >/etc/cron.d/anytls-cleanup <<'EOF'

7 7 * * 0 root apt-get clean && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && journalctl --vacuum-time=5d --vacuum-size=30M && find /tmp /var/tmp -type f -mtime +7 -delete

EOF


chmod 644 /etc/cron.d/anytls-cleanup




# =========================
# 输出
# =========================


echo

echo "=============================="

echo "✅ AnyTLS 部署完成"

echo "=============================="

echo "IPv4 : ${IPV4}"

echo "IPv6 : ${IPV6}"

echo "Port : ${ANYTLS_PORT}"

echo "Password : ${ANYTLS_PASSWORD}"

echo "Mode : $([ "$NET_MODE" = "4" ] && echo IPv4-Only || echo Dual-Stack)"

echo

echo "AnyTLS URI:"

echo "anytls://${ANYTLS_PASSWORD}@${MAIN_IP}:${ANYTLS_PORT}"

echo

echo "=============================="
