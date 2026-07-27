# AnyTLS 一键部署脚本

> 🚀 专为 Debian / Ubuntu 打造的 AnyTLS-go 懒人一键部署方案  
> 支持交互式配置、自动网络优化、自动生成节点链接。  
> **小白用户推荐直接使用 `anytls-go`，复制命令即可完成部署。**

---

# ✨ 简介

本项目提供两个 AnyTLS-go 自动部署脚本：

| 脚本 | 推荐程度 | 特点 | 适合用户 |
|------|------|------|------|
| `anytls-go` | ⭐⭐⭐⭐⭐ | 极简交互，自动生成 IPv4 / IPv6 节点 | 小白、懒人 |
| `anytls` | ⭐⭐⭐⭐ | 支持节点名称、自定义 URI 格式 | 进阶用户 |

---

两个脚本都会自动完成：

- ✅ 安装 AnyTLS-go 最新版本
- ✅ 自动识别 CPU 架构
- ✅ 自动配置 systemd 服务
- ✅ 开机自动启动
- ✅ BBR 网络优化
- ✅ DNS 优化
- ✅ UFW 防火墙配置
- ✅ 自动生成客户端节点链接
- ✅ 每周自动清理系统垃圾

---

# 🚀 快速开始

## ⭐ 小白用户推荐：anytls-go

如果你只是：

> 买 VPS → 搭 AnyTLS 节点 → 手机客户端使用

直接使用这个即可。

使用 root 用户执行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls-go)
```

---

运行后按照提示输入：

```text
==========================================
 AnyTLS 部署脚本
==========================================

当前服务器 IP:
1.2.3.4

以下配置直接按回车将使用默认值

请输入 AnyTLS 端口 [默认: 26216]:

请输入 AnyTLS 密码 [默认: 自动生成]:

请输入网络模式 [默认: 回车=双栈, 输入4=仅IPv4]:
```

全部直接回车即可使用默认配置。

---

# 📦 部署完成示例

```text
==============================
 AnyTLS 部署完成
==============================

IPv4     : 1.2.3.4
IPv6     : 2001:db8::1
Port     : 26216
Password : xxxxxxxx-xxxx-xxxx-xxxx
Version  : v0.xx.xx
Mode     : Dual Stack

==============================
```

自动生成节点：

```text
IPv4:

anytls://password@1.2.3.4:26216


IPv6:

anytls://password@[2001:db8::1]:26216
```

复制到客户端即可使用。

---

# 🔧 进阶用户：install.sh

如果你需要：

- 自定义节点名称
- 生成订阅友好的 URI
- 添加 `udp=1`
- 多节点管理

使用：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls)
```

---

运行时会额外提示：

```text
请输入节点名称:
```

输出示例：

```text
anytls://password@1.2.3.4:26216?udp=1#MyNode
```

适合：

- Clash Meta
- sing-box
- Quantumult X
- Shadowrocket

等客户端管理。

---

# ⚙️ 功能特性

## 🚀 AnyTLS 部署

✅ 自动下载最新版 AnyTLS-go  
✅ 支持 x86_64 / amd64 / arm64  
✅ 自动安装运行文件  
✅ systemd 服务管理  
✅ 自动重启  
✅ 开机启动  


## 🌐 网络优化

✅ 自动开启 BBR  
✅ fq 队列调度  
✅ Cloudflare DNS  
✅ Google DNS  
✅ IPv4 优先解析优化  


## 🔥 防火墙

✅ 自动安装 UFW  
✅ 自动检测 SSH 端口  
✅ 自动开放 SSH  
✅ 自动开放 AnyTLS TCP/UDP 端口  


## 🧹 系统维护

自动添加定时清理任务：

- apt 缓存
- journal 日志
- 临时文件

每周自动执行。

---

# 📁 文件位置

| 文件 | 路径 |
|-|-|
| AnyTLS 主程序 | `/usr/local/bin/anytls-server` |
| 配置目录 | `/etc/anytls` |
| systemd 服务 | `/etc/systemd/system/anytls.service` |
| 定时清理 | `/etc/cron.d/anytls-cleanup` |

---

# 🛠 日常管理

## 查看运行状态

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

## 开机启动

```bash
systemctl enable anytls
```

---

# 🔄 更新

无需卸载。

重新执行安装命令即可：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls-go)
```

脚本会自动：

1. 停止旧服务
2. 获取最新版 AnyTLS-go
3. 更新程序
4. 更新 systemd 配置
5. 重启服务

---

# 🗑 卸载

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

# ⚠️ 注意事项

## 1. 必须使用 root 用户运行

脚本会自动检测权限。

---

## 2. 会修改以下文件

```text
/etc/resolv.conf
/etc/gai.conf
```

如果有特殊 DNS 配置，请提前备份。

---

## 3. 云服务器安全组

请确保开放：

```text
AnyTLS TCP 端口

AnyTLS UDP 端口
```

否则外部无法连接。

---

## 4. 支持系统架构

```text
x86_64
amd64
aarch64
arm64
```

---
