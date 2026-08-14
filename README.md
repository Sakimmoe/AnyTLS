# AnyTLS 一键部署与管理脚本

一个基于 sing-box 内置 AnyTLS 协议的一键安装/管理脚本，专为 Debian / Ubuntu VPS 设计，支持 IPv4 / IPv6 / 双栈，自动生成客户端节点链接。

> 本项目不包含任何隐私信息、密码、密钥或用户数据；脚本只从 sing-box 官方 GitHub Releases 下载二进制，不会回传任何数据。

## 功能特性

- 一键安装 / 重装 AnyTLS（sing-box）
- 自动识别 amd64 / arm64 架构
- 自动生成自签 CA + 服务器证书
- 可选使用自己的域名 + Let's Encrypt 真实证书（自动申请、自动续期）
- 自动生成标准 AnyTLS 客户端链接
- 支持仅 IPv4 / 仅 IPv6 / 双栈（IPv6 入站 + IPv4 出站解锁）
- BBR + fq + TCP 优化，并开启 TCP Fast Open
- 自动检测内存：小于 1G 自动创建 512M Swap，大于等于 1G 自动关闭并清理 Swap
- UFW 防火墙自动放行 SSH 和 AnyTLS 端口
- systemd 服务管理，开机自启
- 支持修改端口 / 密码 / SNI，并自动更新节点链接
- 支持一键更新 sing-box（带备份回滚）
- 每周自动清理系统垃圾
- 提供 `a` / `anytls` 快捷命令

## 系统要求

- Debian 11+ / Ubuntu 20.04+
- root 权限
- amd64 或 arm64 架构
- 需要在防火墙 / 云安全组放行 AnyTLS TCP 端口

## 快速开始

```bash
bash <(curl -sL https://raw.githubusercontent.com/Sakimmoe/AnyTLS/main/anytls)
```

一路回车即可使用默认配置（随机密码、默认端口、双栈）。

安装过程中会询问是否使用自己的域名：

- 输入 `y`：使用你自己的域名，脚本会配置 sing-box 自动申请 Let's Encrypt 证书（需要域名已解析到本服务器，且 80/443 端口空闲）。
- 输入 `n` 或直接回车：继续使用自签证书 + 默认 SNI。

## 菜单说明

| 选项 | 功能 |
| --- | --- |
| 1 | 安装 / 重装 AnyTLS |
| 2 | 更新 sing-box / AnyTLS |
| 3 | 查看节点配置 |
| 4 | 更改端口 |
| 5 | 更改密码 |
| 6 | 更改 SNI / 重新生成证书 |
| 7 | 重启服务 |
| 8 | 查看运行状态 |
| 9 | 卸载 AnyTLS |
| 10 | 重新应用网络优化 / 调整 Swap |
| 0 | 退出 |

## 客户端节点链接

安装完成后脚本会输出类似格式的链接：

```
anytls://密码@服务器IP:端口?sni=域名&udp=1&insecure=1&allowInsecure=1#节点名称
```

支持 sing-box、Clash Meta / Mihomo、Shadowrocket、v2rayN 等支持 AnyTLS 的客户端。

- 使用自签证书时，链接带 `insecure=1`，这是正常设计。
- 使用自己的域名 + Let's Encrypt 真实证书时，链接不带 `insecure`，证书校验更安全。

> 由于默认使用自签证书，链接中带有 `insecure=1`，这是正常设计。如果需要证书固定，可以使用脚本输出的「证书公钥指纹（sing-box pinSHA256）」，在 sing-box 客户端的 `certificate_public_key_sha256` 中填入。

## 网络优化

脚本会统一写入 `/etc/sysctl.conf` 并立即生效：

- BBR 拥塞控制 + fq 队列
- TCP Fast Open（内核 `tcp_fastopen=3` + sing-box `tcp_fast_open: true`）
- 大缓冲区、高并发连接优化
- 同时清理旧的 `/etc/sysctl.d/99-bbr.conf`，避免配置冲突

已安装的服务器可以在菜单中选择 `10. 重新应用网络优化`，不会改动端口、密码等配置。

## Swap 自动调整

脚本会根据服务器内存自动调整 Swap：

- 内存小于 1G 档（实际可用低于约 900M）：自动创建 512M 的 `/swapfile` 并写入 `/etc/fstab`（开机自动挂载）
- 内存 1G 及以上（含 1G 套餐 VPS，实际可用约 900M+）：自动关闭全部 Swap（含系统自带的 swap 分区/文件），并移除 `/etc/fstab` 中所有 swap 条目，防止重启后恢复；同时删除脚本创建的 `/swapfile`

该逻辑在安装时自动执行，也可以随时选择菜单 `10. 重新应用网络优化 / 调整 Swap` 重新调整。

## 防火墙说明

- 脚本会启用 UFW，并默认拒绝所有入站，仅放行 SSH 和 AnyTLS 端口。
- 执行安装 / 改端口时会重置 UFW 规则，请知悉。
- 如果使用云服务商安全组，请额外放行 AnyTLS 的 TCP 端口。
- AnyTLS 实际只使用 TCP，UDP 规则保留但非必需。

## DNS 说明

脚本会禁用并屏蔽 `systemd-resolved` / `resolvconf`，并写入 `1.1.1.1`、`8.8.8.8` 等 DNS，避免 DNS 被覆盖。该操作只适合「服务器仅用于代理」的场景。

## 文件与目录

| 内容 | 路径 |
| --- | --- |
| 主程序 | `/usr/local/bin/sing-box` |
| 配置文件 | `/etc/anytls/config.json` |
| 证书目录 | `/etc/anytls/cert/` |
| systemd 服务 | `/etc/systemd/system/anytls.service` |
| 定时清理 | `/etc/cron.d/anytls-cleanup` |
| 节点信息 | `/etc/anytls/list` |
| 快捷命令 | `/usr/local/bin/a`、`/usr/local/bin/anytls` |

## 卸载

运行脚本后选择 `9. 卸载 AnyTLS`，会停止服务并删除相关文件。

## 常见问题

### 支持 CentOS 吗？

脚本主要针对 Debian / Ubuntu 开发。CentOS 可以运行，但防火墙部分需要手动使用 firewalld 放行端口。

### 为什么节点链接带 `insecure=1`？

因为默认使用自签证书，客户端需要跳过证书校验。想要更安全，可以：

1. 使用脚本输出的公钥指纹做证书固定；
2. 或在安装时选择自己的域名，使用 Let's Encrypt 真实证书，链接将不再需要 `insecure`。

### 修改端口 / 密码 / SNI 后节点链接会更新吗？

会，脚本会自动重新生成节点信息。

### 脚本会收集我的数据吗？

不会。脚本仅调用公共 IP 查询服务获取服务器公网 IP 用于生成节点链接，不包含任何统计、上报或后门代码。

## 免责声明

本项目仅供学习与技术交流使用，请遵守所在地区法律法规，请勿用于非法用途。
