# AnyTLS 一键部署脚本

> 🚀 基于 AnyTLS-go 的一键部署方案  
> 专为 Debian / Ubuntu VPS 打造  
> 支持自动安装、交互式配置、网络优化、生成客户端节点链接。

<p align="center">

⭐ **推荐小白用户直接使用 `anytls-go`**

</p>


---

# ✨ 项目介绍

本项目提供两个 AnyTLS-go 自动部署脚本：

| 脚本 | 推荐 | 特点 | 适合用户 |
|----|----|----|----|
| `anytls-go` | ⭐⭐⭐⭐⭐ 推荐 | 极简交互、自动配置、自动生成节点 | 小白、普通用户 |
| `anytls` | ⭐⭐⭐⭐ | 更多自定义选项、节点名称、URI格式 | 高级用户 |

---

## 为什么推荐 `anytls-go`？

如果你的需求只是：

```
购买 VPS
 ↓
安装 AnyTLS
 ↓
生成节点
 ↓
手机 / 电脑客户端使用
```

那么：

✅ 不需要修改配置文件  
✅ 不需要了解 sing-box  
✅ 不需要手动生成链接  
✅ 不需要额外设置 TLS 参数  


直接运行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls-go)
```

即可完成部署。


---

# 🚀 快速开始


## ⭐ 推荐：anytls-go

使用 root 用户执行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls-go)
```


脚本会自动完成：

```
检测系统
   ↓
安装依赖
   ↓
下载最新版 AnyTLS-go
   ↓
配置服务
   ↓
开启网络优化
   ↓
生成节点链接
```


---

# 📌 安装过程示例


```text
==========================================
 AnyTLS 部署脚本
==========================================


当前服务器 IP:

1.2.3.4


以下配置直接按回车使用默认值


请输入 AnyTLS 端口 [默认: 26216]:


请输入 AnyTLS 密码 [默认: 自动生成]:


请输入网络模式:
默认: 双栈

输入4: 仅IPv4
```


普通用户：

一路回车即可。


---

# 🎉 部署完成示例


```text
================================
 AnyTLS 部署完成
================================

IPv4:
1.2.3.4

IPv6:
2001:db8::1

Port:
26216

Password:
xxxxxxxx-xxxx-xxxx-xxxx

Mode:
Dual Stack

================================
```


自动生成节点：


IPv4:

```
anytls://password@1.2.3.4:26216
```


IPv6:

```
anytls://password@[2001:db8::1]:26216
```


复制到客户端即可使用。


支持：

- sing-box
- Clash Meta
- Shadowrocket
- Quantumult X
- 其他支持 AnyTLS 的客户端


---

# 🔧 高级用户：anytls


如果你需要：

- 自定义节点名称
- 自定义 URI 参数
- 添加节点备注
- 更方便订阅管理


可以使用：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls)
```


示例：

```
anytls://password@1.2.3.4:26216?udp=1#MyNode
```


适合：

- 多节点管理
- 自建机场用户
- 需要自定义节点信息的用户


---

# ⚙️ 功能特性


## 🚀 AnyTLS 自动部署

- ✅ 自动下载最新版 AnyTLS-go
- ✅ 自动识别 CPU 架构
- ✅ 支持 amd64 / x86_64 / arm64
- ✅ 自动安装服务
- ✅ systemd 管理
- ✅ 开机自动启动
- ✅ 自动生成客户端链接


---

## 🌐 网络优化


自动优化：

- ✅ 开启 BBR
- ✅ fq 队列调度
- ✅ TCP 参数优化
- ✅ DNS 优化
- ✅ IPv4 / IPv6 双栈支持


---

## 🔥 防火墙配置


自动处理：

- ✅ 安装 UFW
- ✅ 保留 SSH 端口
- ✅ 开放 AnyTLS TCP 端口
- ✅ 开放 AnyTLS UDP 端口


避免：

```
安装完成后无法 SSH 登录
```

---

## 🧹 自动维护


自动添加定时任务：

```
每周清理系统垃圾
```


包括：

- apt 缓存
- systemd 日志
- 临时文件


---

# 📁 文件目录


| 内容 | 路径 |
|-|-|
| AnyTLS 程序 | `/usr/local/bin/anytls-server` |
| 配置文件 | `/etc/anytls` |
| systemd 服务 | `/etc/systemd/system/anytls.service` |
| 自动清理 | `/etc/cron.d/anytls-cleanup` |


---

# 🛠 服务管理


## 查看状态

```bash
systemctl status anytls
```


## 查看日志

```bash
journalctl -u anytls -f
```


## 重启

```bash
systemctl restart anytls
```


## 停止

```bash
systemctl stop anytls
```


## 开机启动

```bash
systemctl enable anytls
```


---

# 🔄 更新


重新执行安装脚本：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls-go)
```


自动完成：

1. 停止旧服务
2. 下载最新版
3. 更新程序
4. 更新配置
5. 重启服务


---

# 🗑 卸载


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


## VPS 要求

推荐：

- Debian 11+
- Debian 12+
- Ubuntu 20.04+
- Ubuntu 22.04+
- Ubuntu 24.04+

需要：

- root 权限
- 开放 TCP 端口


---

# 📄 开源协议


本项目仅用于学习和技术交流。

感谢：

- AnyTLS-go 项目
- sing-box 项目


---

# ⭐ Star 支持


如果这个项目帮助到了你：

欢迎点一个 ⭐ Star 支持项目发展！

