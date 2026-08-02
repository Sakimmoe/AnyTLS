#!/usr/bin/env bash
# AnyTLS (sing-box) 全功能健康检测脚本
# 检测安装状态、服务运行、配置有效性、防火墙、定时任务等

set -euo pipefail

CONFIG_DIR="/etc/anytls"
CONFIG_JSON="${CONFIG_DIR}/config.json"
LIST_FILE="${CONFIG_DIR}/list"
STACK_FILE="${CONFIG_DIR}/.stack"
ANYTLS_SERVICE="anytls.service"
ANYTLS_SERVICE_FILE="/etc/systemd/system/${ANYTLS_SERVICE}"

# 颜色
Font="\033[0m"
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Cyan="\033[36m"
BGreen="\033[92m"
BRed="\033[91m"
BYellow="\033[93m"
BCyan="\033[96m"

OK="${Green}[✓]${Font}"
FAIL="${Red}[✗]${Font}"
WARN="${Yellow}[!]${Font}"
INFO="${Cyan}[i]${Font}"

hr() { printf '%*s\n' 60 '' | tr ' ' '-'; }

print_ok()  { echo -e "  ${OK}  $1"; }
print_fail() { echo -e "  ${FAIL}  $1"; }
print_warn() { echo -e "  ${WARN}  $1"; }
print_info() { echo -e "  ${INFO}  $1"; }

# 检测 sing-box 二进制
check_binary() {
  echo -e "\n${BCyan}【1/10】sing-box 二进制${Font}"
  if [[ -x /usr/local/bin/sing-box ]]; then
    local ver=$(/usr/local/bin/sing-box version 2>/dev/null | awk '/version/{print $NF}' || echo "unknown")
    print_ok "已安装: ${BGreen}${ver}${Font}"
  else
    print_fail "未找到 /usr/local/bin/sing-box"
  fi
}

# 检测 systemd 服务
check_service() {
  echo -e "\n${BCyan}【2/10】systemd 服务${Font}"
  if [[ -f "$ANYTLS_SERVICE_FILE" ]]; then
    print_ok "服务文件存在: ${ANYTLS_SERVICE_FILE}"

    if systemctl is-active "$ANYTLS_SERVICE" >/dev/null 2>&1; then
      print_ok "服务状态: ${BGreen}运行中${Font}"
    elif systemctl is-failed "$ANYTLS_SERVICE" >/dev/null 2>&1; then
      print_fail "服务状态: ${BRed}启动失败${Font}"
      echo -e "\n${Yellow}最近 10 条日志:${Font}"
      journalctl -u "$ANYTLS_SERVICE" -n 10 --no-pager 2>/dev/null || true
    else
      print_warn "服务状态: ${BYellow}已停止${Font}"
    fi

    if systemctl is-enabled "$ANYTLS_SERVICE" >/dev/null 2>&1; then
      print_ok "开机自启: 已启用"
    else
      print_warn "开机自启: 未启用"
    fi
  else
    print_fail "服务文件不存在"
  fi
}

# 检测配置文件
check_config() {
  echo -e "\n${BCyan}【3/10】配置文件${Font}"
  if [[ -f "$CONFIG_JSON" ]]; then
    print_ok "配置文件存在: ${CONFIG_JSON}"

    # 检查 JSON 有效性
    if jq empty "$CONFIG_JSON" 2>/dev/null; then
      print_ok "JSON 格式: 有效"
    else
      print_fail "JSON 格式: 无效"
      return
    fi

    # 检查 sing-box 配置有效性
    if /usr/local/bin/sing-box check -c "$CONFIG_JSON" 2>/dev/null; then
      print_ok "sing-box 校验: 通过"
    else
      print_fail "sing-box 校验: 失败"
      /usr/local/bin/sing-box check -c "$CONFIG_JSON" 2>&1 | head -5 || true
    fi

    # 提取关键信息
    local port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_JSON" 2>/dev/null || echo "N/A")
    local listen=$(jq -r '.inbounds[0].listen' "$CONFIG_JSON" 2>/dev/null || echo "N/A")
    local pass=$(jq -r '.inbounds[0].users[0].password' "$CONFIG_JSON" 2>/dev/null || echo "N/A")
    local tag=$(jq -r '.inbounds[0].tag' "$CONFIG_JSON" 2>/dev/null || echo "N/A")

    print_info "监听地址: ${listen}"
    print_info "监听端口: ${port}"
    print_info "节点标签: ${tag}"

    # 检测 domain_resolver / domain_strategy
    local has_resolver=$(jq 'has("outbounds") and .outbounds[0]? | has("domain_resolver")' "$CONFIG_JSON" 2>/dev/null || echo "false")
    local has_strategy=$(jq 'has("outbounds") and .outbounds[0]? | has("domain_strategy")' "$CONFIG_JSON" 2>/dev/null || echo "false")

    if [[ "$has_resolver" == "true" ]]; then
      local resolver_server=$(jq -r '.outbounds[0].domain_resolver.server' "$CONFIG_JSON" 2>/dev/null || echo "N/A")
      local resolver_strategy=$(jq -r '.outbounds[0].domain_resolver.strategy' "$CONFIG_JSON" 2>/dev/null || echo "N/A")
      print_ok "出站解析器: ${resolver_server} / ${BGreen}${resolver_strategy}${Font}"
    elif [[ "$has_strategy" == "true" ]]; then
      local strategy=$(jq -r '.outbounds[0].domain_strategy' "$CONFIG_JSON" 2>/dev/null || echo "N/A")
      print_warn "出站策略(旧格式): ${strategy} (1.14将废弃)"
    else
      print_warn "未配置出站 IP 策略，可能走系统默认"
    fi

    # 检测 DNS 配置
    if jq 'has("dns")' "$CONFIG_JSON" >/dev/null 2>&1; then
      local dns_count=$(jq '.dns.servers | length' "$CONFIG_JSON" 2>/dev/null || echo "0")
      print_info "DNS 服务器数: ${dns_count}"
    else
      print_info "未配置 DNS 块（使用系统默认）"
    fi
  else
    print_fail "配置文件不存在: ${CONFIG_JSON}"
  fi
}

# 检测证书
check_cert() {
  echo -e "\n${BCyan}【4/10】TLS 证书${Font}"
  local cert_dir="${CONFIG_DIR}/cert"
  if [[ -d "$cert_dir" ]]; then
    local files=("ca.crt" "ca.key" "cert.pem" "private.key")
    for f in "${files[@]}"; do
      if [[ -s "${cert_dir}/${f}" ]]; then
        print_ok "证书文件: ${f}"
      else
        print_fail "证书文件缺失: ${f}"
      fi
    done

    if [[ -s "${cert_dir}/cert.pem" ]]; then
      local sni=$(openssl x509 -noout -ext subjectAltName -in "${cert_dir}/cert.pem" 2>/dev/null | awk -F 'DNS:' '/DNS:/{gsub(/,.*/,"",$2); print $2}')
      local expiry=$(openssl x509 -noout -dates -in "${cert_dir}/cert.pem" 2>/dev/null | grep notAfter | cut -d= -f2)
      print_info "证书 SNI: ${sni:-N/A}"
      print_info "证书过期: ${expiry:-N/A}"
    fi
  else
    print_fail "证书目录不存在: ${cert_dir}"
  fi
}

# 检测端口监听
check_ports() {
  echo -e "\n${BCyan}【5/10】端口监听${Font}"
  if [[ -f "$CONFIG_JSON" ]]; then
    local port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_JSON" 2>/dev/null || echo "")
    if [[ -n "$port" && "$port" != "null" ]]; then
      if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":${port}"; then
          print_ok "端口 ${port} 正在监听"
          ss -tuln | grep ":${port}" | while read line; do
            echo -e "    ${Cyan}${line}${Font}"
          done
        else
          print_fail "端口 ${port} 未监听"
        fi
      elif command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":${port}"; then
          print_ok "端口 ${port} 正在监听"
        else
          print_fail "端口 ${port} 未监听"
        fi
      else
        print_warn "未安装 ss/netstat，无法检测端口"
      fi
    fi
  fi
}

# 检测防火墙
check_firewall() {
  echo -e "\n${BCyan}【6/10】防火墙 (UFW)${Font}"
  if command -v ufw >/dev/null 2>&1; then
    if ufw status | grep -q "Status: active"; then
      print_ok "UFW 已启用"

      if [[ -f "$CONFIG_JSON" ]]; then
        local port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_JSON" 2>/dev/null || echo "")
        if ufw status | grep -q "${port}/tcp"; then
          print_ok "TCP 端口 ${port} 已放行"
        else
          print_warn "TCP 端口 ${port} 未放行"
        fi
        if ufw status | grep -q "${port}/udp"; then
          print_ok "UDP 端口 ${port} 已放行"
        else
          print_warn "UDP 端口 ${port} 未放行"
        fi
      fi

      # 检查 IPv6 支持
      if grep -q "IPV6=yes" /etc/default/ufw 2>/dev/null; then
        print_ok "UFW IPv6 支持: 已启用"
      else
        print_warn "UFW IPv6 支持: 未启用"
      fi
    else
      print_warn "UFW 未启用"
    fi
  else
    print_warn "未安装 UFW"
  fi
}

# 检测定时任务
check_cron() {
  echo -e "\n${BCyan}【7/10】定时任务${Font}"
  local cron_file="/etc/cron.d/anytls-cleanup"
  local clean_script="/usr/local/bin/anytls-cleanup.sh"

  if [[ -f "$cron_file" ]]; then
    print_ok "定时任务文件: ${cron_file}"
    cat "$cron_file" | sed 's/^/    /'
  else
    print_fail "定时任务文件不存在"
  fi

  if [[ -x "$clean_script" ]]; then
    print_ok "清理脚本存在且可执行"
  else
    print_fail "清理脚本缺失或不可执行"
  fi
}

# 检测快捷命令
check_shortcuts() {
  echo -e "\n${BCyan}【8/10】快捷命令${Font}"
  local cmds=("/usr/local/bin/a" "/usr/local/bin/anytls" "/usr/local/bin/anytls-panel.sh")
  for cmd in "${cmds[@]}"; do
    if [[ -x "$cmd" ]]; then
      print_ok "快捷命令: ${cmd}"
    else
      print_fail "快捷命令缺失: ${cmd}"
    fi
  done

  if [[ -f "${CONFIG_DIR}/anytls-panel.sh" ]]; then
    print_ok "备份面板脚本: ${CONFIG_DIR}/anytls-panel.sh"
  else
    print_warn "备份面板脚本缺失"
  fi
}

# 检测网络栈
check_network_stack() {
  echo -e "\n${BCyan}【9/10】网络栈类型${Font}"

  local ipv4=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "")
  local ipv6=$(curl -6 -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null || echo "")

  if [[ -n "$ipv4" ]]; then
    print_ok "IPv4 外网可达: ${ipv4}"
  else
    print_fail "IPv4 外网不可达"
  fi

  if [[ -n "$ipv6" ]]; then
    print_ok "IPv6 外网可达: ${ipv6}"
  else
    print_warn "IPv6 外网不可达"
  fi

  if [[ -f "$STACK_FILE" ]]; then
    local stack=$(cat "$STACK_FILE" 2>/dev/null || echo "unknown")
    case "$stack" in
      dual)   print_ok "安装时栈类型: 双栈 (IPv6入+IPv4出解锁)" ;;
      v4only) print_ok "安装时栈类型: 仅 IPv4" ;;
      v6only) print_ok "安装时栈类型: 仅 IPv6" ;;
      *)      print_warn "安装时栈类型: 未知" ;;
    esac
  else
    print_warn "未记录栈类型 (.stack 文件缺失)"
  fi
}

# 检测节点信息
check_node_info() {
  echo -e "\n${BCyan}【10/10】节点信息${Font}"
  if [[ -f "$LIST_FILE" ]]; then
    print_ok "节点信息文件: ${LIST_FILE}"
    echo ""
    cat "$LIST_FILE" | sed 's/^/    /'
  else
    print_fail "节点信息文件不存在"
  fi
}

# 综合评分
final_score() {
  hr
  local score=0
  local total=0

  # 简单评分
  [[ -x /usr/local/bin/sing-box ]] && ((score+=10))
  ((total+=10))

  systemctl is-active "$ANYTLS_SERVICE" >/dev/null 2>&1 && ((score+=10))
  ((total+=10))

  [[ -f "$CONFIG_JSON" ]] && ((score+=10))
  ((total+=10))

  [[ -f "${CONFIG_DIR}/cert/cert.pem" ]] && ((score+=10))
  ((total+=10))

  [[ -f "/etc/cron.d/anytls-cleanup" ]] && ((score+=10))
  ((total+=10))

  [[ -x /usr/local/bin/a ]] && ((score+=10))
  ((total+=10))

  local percent=$(( score * 100 / total ))

  if (( percent >= 90 )); then
    echo -e "\n${BGreen}综合评分: ${percent}% (状态优秀)${Font}"
  elif (( percent >= 70 )); then
    echo -e "\n${BYellow}综合评分: ${percent}% (状态良好，部分功能待完善)${Font}"
  elif (( percent >= 50 )); then
    echo -e "\n${Yellow}综合评分: ${percent}% (状态一般，建议检查)${Font}"
  else
    echo -e "\n${BRed}综合评分: ${percent}% (状态较差，需要修复)${Font}"
  fi

  echo -e "\n${Cyan}快速修复建议:${Font}"
  if ! systemctl is-active "$ANYTLS_SERVICE" >/dev/null 2>&1; then
    echo -e "  • 服务未运行，尝试: ${Yellow}systemctl restart anytls${Font}"
    echo -e "  • 查看日志: ${Yellow}journalctl -u anytls -n 30 --no-pager${Font}"
  fi
  if ! [[ -f "$CONFIG_JSON" ]]; then
    echo -e "  • 配置缺失，建议重新运行安装脚本"
  fi
  if ! [[ -x /usr/local/bin/a ]]; then
    echo -e "  • 快捷命令缺失，建议重新运行安装脚本"
  fi
}

# 主函数
main() {
  clear
  echo -e "${BCyan}╔════════════════════════════════════════════════════════════╗${Font}"
  echo -e "${BCyan}║        AnyTLS (sing-box) 全功能健康检测脚本              ║${Font}"
  echo -e "${BCyan}╚════════════════════════════════════════════════════════════╝${Font}"

  check_binary
  check_service
  check_config
  check_cert
  check_ports
  check_firewall
  check_cron
  check_shortcuts
  check_network_stack
  check_node_info
  final_score

  hr
  echo -e "\n${Cyan}检测完成。如需重新安装，运行: ${Yellow}bash anytls.sh${Font}"
  echo ""
}

main
