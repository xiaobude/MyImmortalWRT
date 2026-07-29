# MyOpenWRT - RK3566 ARM 平台精简固件项目

基于 OpenWrt 定制，专为瑞芯微 RK3566 芯片（NanoPi R3S / 4K 电视盒子开发板，1GB 内存）打造的嵌入式 Linux 发行版。

---

## 🎯 软件功能清单

本项目针对 **1GB 内存与存储限制** 进行了定制，精简了非必要的服务（如 Docker、Samba、Aria2、Python 等），聚焦于高性能路由、网络加速与安全组网。

### ✅ 选定包含的功能：
- **LuCI**：Web 管理界面
- **Firewall4 + nftables**：下一代 Linux 原生防火墙架构
- **MosDNS**：智能 DNS 分流与解析
- **OpenClash**：基于 Clash 内核的规则代理
- **OpenAppFilter**：应用过滤与家长控制
- **Tailscale**：零配置虚拟局域网 / 组网
- **WireGuard**：原生轻量级 VPN 支持

### ❌ 精简排除的功能（已屏蔽，避免内存浪费）：
- Docker 容器引擎 (`dockerd`)
- Samba / KSMBD / NFS / FTP 文件共享
- Aria2 / qBittorrent 下载服务
- NAS 磁盘休眠与共享服务
- Python 3 运行时环境

---

## 📁 项目结构

```
.
├── config.mk            # 全局构建配置与功能包定义
├── Makefile             # 主构建 Makefile (kernel, u-boot, plugins, firmware)
├── build.sh             # 自动化构建主脚本
├── compile-plugins.sh   # OpenWrt SDK 下载与选定插件仓库配置脚本
├── pack-image.sh        # SquashFS 与固件镜像打包脚本
├── kernel.config        # Linux 内核配置文件
└── u-boot.config        # U-Boot 引导程序配置文件
```

---

## 🛠️ 编译与构建步骤

### 1. 安装编译依赖
```bash
sudo apt update
sudo apt install -y build-essential gcc-aarch64-linux-gnu \
    autoconf automake libtool pkg-config \
    libncurses5-dev libssl-dev libelf-dev \
    texinfo git wget unzip mksquashfs
```

### 2. 初始化环境与准备插件
```bash
./compile-plugins.sh
```
*该脚本会自动下载对应的 OpenWrt 23.05.3 SDK，并自动拉取 OpenClash、MosDNS、OpenAppFilter 等源码仓库。*

### 3. 打包系统固件
```bash
make firmware
```
*完成后将在根目录生成 `MyOpenWRT-1.0.0-rk3566.img.gz`。*

---

## 📝 默认配置参数

| 参数 | 默认值 |
|------|-----|
| 默认 IP | `192.168.2.1` |
| 默认子网掩码 | `255.255.255.0` |
| DNS | `114.114.114.114`, `223.5.5.5` |
| 分区格式 | SquashFS (LZMA 压缩, 只读) + JFFS2 (可写) |

可优先下载支持“恢复出厂设置”的 squashfs-sysupgrade.img.gz（28.8 MB的版本）
