#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ANYTLS_PORT=${1:-26216}
ANYTLS_PASSWORD=${2:-kokonoeyukari}
NET_MODE=${3:-}
GITHUB_API="https://api.github.com/repos/anytls/anytls-go/releases/latest"

echo "=========================================="
echo " AnyTLS 部署脚本"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
    echo "Error: 请使用 root 用户运行"
    exit 1
fi

echo "📦 安装依赖..."
# 隐藏 Debian 旧系统（如 bullseye）源失效导致的吓人报错，且不会中断脚本
apt-get update -qq >/dev/null 2>&1 || true
apt-get install -y -qq wget unzip curl ufw iproute2 cron jq tar >/dev/null 2>&1 || true

echo "🌐 优化网络配置..."
grep -q "precedence ::ffff:0:0/96 100" /etc/gai.conf 2>/dev/null || echo "precedence ::ffff:0:0/96 100" >> /etc/gai.conf

systemctl disable systemd-resolved --now >/dev/null 2>&1 || true
systemctl mask systemd-resolved >/dev/null 2>&1 || true

# 【关键修复】：必须先解锁 DNS 配置文件，防止重复运行脚本时因文件被锁导致 rm 报错中断
chattr -i /etc/resolv.conf >/dev/null 2>&1 || true
rm -f /etc/resolv.conf >/dev/null 2>&1 || true

cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 2606:4700:4700::1111
nameserver 2001:4860:4860::8888
EOF
# 写入完成后重新上锁，防止被系统其他服务篡改
chattr +i /etc/resolv.conf >/dev/null 2>&1 || true

cat > /etc/sysctl.d/99-bbr.conf << 'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system >/dev/null 2>&1 || true

echo "📡 获取服务器 IP..."
IPV4=$(curl -4 -s --max-time 5 https://api.ipify.org || echo "无")
IPV6=$(curl -6 -s --connect-timeout 3 https://api64.ipify.org || echo "无")
MAIN_IP=$([ "$IPV4" != "无" ] && echo "$IPV4" || echo "$IPV6")

if [ "$NET_MODE" = "4" ]; then
    LISTEN_ADDR="0.0.0.0"
else
    LISTEN_ADDR="[::]"
fi

echo "🚀 部署 AnyTLS..."
systemctl stop anytls >/dev/null 2>&1 || true
sleep 1

if ss -tlnp | grep -q ":${ANYTLS_PORT} "; then
    echo "❌ 端口 ${ANYTLS_PORT} 已被占用"
    ss -tlnp | grep ":${ANYTLS_PORT} "
    exit 1
fi

case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "❌ 不支持的架构"; exit 1 ;;
esac

echo "⬇️ 获取 AnyTLS 最新版本..."
VERSION=$(curl -s ${GITHUB_API} | jq -r '.tag_name' 2>/dev/null || true)
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    echo "❌ 获取版本失败，请检查网络"
    exit 1
fi

ASSET_URL=$(curl -s ${GITHUB_API} | jq -r ".assets[].browser_download_url" | grep -i "linux" | grep -i "${ARCH}" | grep -v -i "sha256" | head -1 || true)
if [ -z "$ASSET_URL" ]; then
    echo "❌ 未找到适用于 Linux ${ARCH} 的下载文件"
    exit 1
fi

TMP=$(mktemp -d)
wget -q -O ${TMP}/anytls.pkg "$ASSET_URL" || {
    echo "❌ AnyTLS 下载失败"
    rm -rf ${TMP}
    exit 1
}

rm -f /usr/local/bin/anytls-server
if [[ "$ASSET_URL" == *.tar.gz ]]; then
    tar -xf ${TMP}/anytls.pkg -C ${TMP}
elif [[ "$ASSET_URL" == *.zip ]]; then
    unzip -q -o ${TMP}/anytls.pkg -d ${TMP}
else
    cp ${TMP}/anytls.pkg ${TMP}/anytls-server
fi

FILE=$(find ${TMP} -type f \( -name "anytls*" -o -name "server*" \) ! -name "*.pkg" | head -1)
if [ -z "$FILE" ]; then
    echo "❌ 解压后未找到二进制文件"
    rm -rf ${TMP}
    exit 1
fi

cp "$FILE" /usr/local/bin/anytls-server
chmod +x /usr/local/bin/anytls-server
rm -rf ${TMP}

mkdir -p /etc/anytls

cat > /etc/systemd/system/anytls.service << EOF
[Unit]
Description=AnyTLS Server Service
After=network.target

[Service]
Type=simple
LimitNOFILE=65535
ExecStart=/usr/local/bin/anytls-server -l ${LISTEN_ADDR}:${ANYTLS_PORT} -p ${ANYTLS_PASSWORD}
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable anytls >/dev/null 2>&1 || true
systemctl restart anytls >/dev/null 2>&1 || true
sleep 2

if ! systemctl is-active --quiet anytls; then
    echo "❌ AnyTLS 启动失败"
    journalctl -u anytls -n 20 --no-pager
    exit 1
fi

echo "🛡️ 配置防火墙..."
systemctl unmask ufw >/dev/null 2>&1 || true
systemctl enable --now ufw >/dev/null 2>&1 || true

ufw --force reset >/dev/null 2>&1 || true
ufw default deny incoming >/dev/null 2>&1 || true
ufw default allow outgoing >/dev/null 2>&1 || true

SSH_PORT=""
if [ -f /etc/ssh/sshd_config ]; then
    SSH_PORT=$(grep -Ei '^\s*Port\s+' /etc/ssh/sshd_config | head -1 | awk '{print $2}' | tr -d '\r\n' || true)
fi
if [ -z "$SSH_PORT" ] && [ -d /etc/ssh/sshd_config.d ]; then
    SSH_PORT=$(grep -Ei '^\s*Port\s+' /etc/ssh/sshd_config.d/*.conf 2>/dev/null | head -1 | awk '{print $2}' | tr -d '\r\n' || true)
fi
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]]; then
    SSH_PORT=22
fi

ufw allow 22/tcp comment 'SSH fallback' >/dev/null 2>&1 || true
ufw allow ${SSH_PORT}/tcp comment 'SSH' >/dev/null 2>&1 || true
ufw allow ${ANYTLS_PORT}/tcp comment 'AnyTLS TCP' >/dev/null 2>&1 || true
ufw allow ${ANYTLS_PORT}/udp comment 'AnyTLS UDP' >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true
ufw reload >/dev/null 2>&1 || true
echo "✅ UFW 配置完成"

echo "🧹 配置定时清理..."
cat > /etc/cron.d/anytls-cleanup << 'CRONEOF'
7 7 * * 0 root /bin/bash -c 'apt-get clean && apt-get autoclean -y && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && journalctl --vacuum-time=5d --vacuum-size=30M && find /tmp /var/tmp -type f -mtime +7 -delete' >/dev/null 2>&1
CRONEOF
chmod 644 /etc/cron.d/anytls-cleanup

echo -e "\n=============================="
echo " ✅ AnyTLS 部署完成"
echo "=============================="
echo " IPv4     : $IPV4"
echo " IPv6     : $IPV6"
echo " Port     : $ANYTLS_PORT"
echo " Password : $ANYTLS_PASSWORD"
echo " Mode     : $([ "$NET_MODE" = "4" ] && echo "IPv4 Only" || echo "Dual Stack")"
echo "=============================="
echo "客户端 URI 配置："
echo "anytls://${ANYTLS_PASSWORD}@${MAIN_IP}:${ANYTLS_PORT}"
echo "=============================="
