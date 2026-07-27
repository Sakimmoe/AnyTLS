# AnyTLS 一键部署脚本

> 一个简单、高效的 **AnyTLS-go** 代理服务一键部署脚本，专为 Debian / Ubuntu 系统设计。  
> 支持参数化配置、系统网络自动优化，即开即用。

---

## 简介

本脚本可以一键在 Linux 服务器上完成 **AnyTLS-go** 的部署，自动处理依赖安装、网络优化、systemd 服务配置、UFW 防火墙和定时清理任务。

**推荐使用场景**：全新服务器快速搭建个人 AnyTLS 代理节点。

---

## 特性

- ✅ 自动下载安装最新版本 **AnyTLS-go**
- ✅ 自动识别 `amd64` / `arm64` 架构
- ✅ 自动启用 **BBR** 拥塞控制 + `fq` qdisc
- ✅ 配置 Cloudflare + Google 公共 DNS（同时支持 IPv4/IPv6）
- ✅ 设置 IPv4 优先解析（`gai.conf`）
- ✅ 使用 systemd 管理服务（开机自启 + 失败自动重启）
- ✅ 自动配置 UFW 防火墙（仅开放 SSH + AnyTLS 端口）
- ✅ 内置每周自动清理任务（apt 缓存、journal 日志、/tmp 临时文件）
- ✅ 支持 **双栈（IPv4+IPv6）** 或 **纯 IPv4** 模式
- ✅ 部署成功后自动输出 AnyTLS 客户端 URI 配置
- ✅ 重新运行脚本即可更新二进制或修改端口/密码（自动覆盖旧配置）

---

# 部署方法

使用 **root** 用户在服务器终端执行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/install.sh) [端口] [密码] [模式]
```

> **提示：** 请将 `[端口] [密码] [模式]` 替换为你自己的参数。

---

# 默认值（不带参数时）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 端口 | `26216` | AnyTLS 监听端口 |
| 密码 | `kokonoeyukari` | AnyTLS 认证密码 |
| 模式 | 双栈 | IPv4 + IPv6 |

---

# 参数说明

| 参数 | 位置 | 说明 | 示例 |
|------|------|------|------|
| 端口 | `$1` | AnyTLS 服务监听端口 | `26216` |
| 密码 | `$2` | AnyTLS 认证密码（建议使用复杂密码） | `MyPassword2026` |
| 模式 | `$3` | `4` = 仅 IPv4<br>留空 = 双栈模式 | `4` |

---

# 使用示例

## 1. 默认双栈部署（最简单）

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/install.sh)
```

---

## 2. 自定义端口 + 密码（双栈）

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/install.sh) 12345 MyStrongPassword2026
```

---

## 3. 仅 IPv4 模式

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/install.sh) 26216 kokonoeyukari 4
```

---

# 部署成功后

脚本执行完成后会输出：

```
==============================
 ✅ AnyTLS 部署完成
==============================
 IPv4     : xxx.xxx.xxx.xxx
 IPv6     : xxxx:xxxx:xxxx::xxxx
 Port     : 26216
 Password : kokonoeyukari
 Mode     : Dual Stack
==============================
客户端 URI 配置：
anytls://kokonoeyukari@your_server_ip:26216
==============================
```

---

# 日常管理命令

## 查看服务状态

```bash
systemctl status anytls
```

---

## 查看实时日志

```bash
journalctl -u anytls -f
```

---

## 重启服务

```bash
systemctl restart anytls
```

---

## 停止服务

```bash
systemctl stop anytls
```

---

## 设置开机启动

```bash
systemctl enable anytls
```

---

# 重要文件位置

**AnyTLS 主程序**

```
/usr/local/bin/anytls-server
```

**配置目录**

```
/etc/anytls
```

**systemd 服务文件**

```
/etc/systemd/system/anytls.service
```

---

# 修改配置 / 更新 AnyTLS

无需卸载，直接重新运行部署命令即可。

脚本会自动：

1. 停止旧 AnyTLS 服务
2. 获取最新 AnyTLS-go Release
3. 更新二进制文件
4. 覆盖 systemd 服务配置
5. 重启 AnyTLS 服务

适合：

- 修改端口
- 修改密码
- 更新版本
- 重新部署节点

---

# 卸载

执行：

```bash
systemctl stop anytls 2>/dev/null || true
systemctl disable anytls 2>/dev/null || true

rm -f /etc/systemd/system/anytls.service
systemctl daemon-reload

rm -f /usr/local/bin/anytls-server
rm -rf /etc/anytls

rm -f /etc/cron.d/anytls-cleanup

echo "✅ AnyTLS 已完全卸载"
```

---

# 注意事项

1. **必须使用 root 用户运行**，脚本会自动检测 `$EUID`。
2. 脚本会修改 `/etc/resolv.conf` 和 `/etc/gai.conf`，如有特殊 DNS 需求请提前备份。
3. UFW 默认拒绝所有入站连接，仅放行 SSH（自动检测端口）和 AnyTLS 端口。
4. 请同步在云服务商安全组/防火墙中放行 AnyTLS 对应端口。
5. 支持架构：
   - `x86_64`
   - `amd64`
   - `aarch64`
   - `arm64`
6. AnyTLS 协议表现与网络环境有关，请自行测试。
7. 本脚本仅供学习和个人使用，请勿用于任何非法用途。
