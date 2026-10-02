# MyImmortalWRT - RK3328 ARM 平台精简固件项目

基于 ImmortalWrt 定制，专为瑞芯微 **RK3328**（FriendlyElec **NanoPi R2S**，1GB 内存）打造的嵌入式 Linux 发行版。

固件由 GitHub Actions 用**完整 ImmortalWrt 源码树**编译，产物是官方镜像结构（含 GPT 分区表、U-Boot/idbloader、内核 FIT、rootfs），可直接 TF 卡启动。

---

## 🎯 软件功能清单

针对 **1GB 内存与存储限制**做了精简，聚焦路由、代理分流与安全组网。

### ✅ 包含
- **LuCI** Web 管理界面（简体中文）
- **Firewall4 + nftables**
- **OpenClash**：基于 Clash 内核的规则代理（v0.47.075，来自 ImmortalWrt luci feed）
- **Tailscale + WireGuard**：零配置虚拟局域网 / 组网（ImmortalWrt v25.12.1 的 feeds 里没有 `luci-app-tailscale`，需用 `tailscale` 命令行登录与配置；WireGuard 有完整 LuCI 界面）
- **ttyd**：网页终端
- bash / curl / ca-bundle / unzip / dropbear

### ❌ 精简排除
- MosDNS、OpenAppFilter（`mosdns` 在 packages feed 里，但 `luci-app-mosdns`、`luci-app-oaf` 都不在，要加必须挂第三方仓库）
- Docker、Samba/KSMBD/NFS/FTP、Aria2/qBittorrent、Python 3

---

## 📁 项目结构

```
.
├── .github/workflows/build-immortalwrt.yml   # 唯一的构建入口 (GitHub Actions)
├── immortalwrt-rk3328.config                 # 板型与软件包选择 (RK3328 / NanoPi R2S)
├── files/etc/config/network                  # 根文件系统覆盖: LAN=eth1, 192.168.2.1
└── pack-image-x86.sh / build-with-ib.sh      # 与 R2S 无关的 x86_64 软路由打包脚本
```

> 本项目原先还有一套 `config.mk` / `Makefile` / `compile-plugins.sh` / `pack-image.sh`
> 的"本地打包"流程，已删除。OpenWrt **SDK** 只能交叉编译出 `.ipk`，不产生内核、
> U-Boot、idbloader 与分区表，因此那条路只会产出无分区表、点不亮的假镜像。

---

## 🛠️ 构建步骤

固件在云端编译，本地不需要交叉工具链、不需要 WSL，也不需要下载 ImmortalWrt SDK。
见 [README_CLOUD_BUILD.md](README_CLOUD_BUILD.md)：

```bash
git add -A && git commit -m "build" && git push
```
推送后在仓库 **Actions** 页触发工作流，产物在 Artifacts / Releases 下载。

---

## 📝 默认配置参数

| 参数 | 默认值 |
|------|--------|
| 默认 IP | `192.168.2.1` |
| 子网掩码 | `255.255.255.0` |
| DNS | `114.114.114.114`, `223.5.5.5` |
| LuCI 账号 | `root` / 空密码（首次登录请设置） |
| LAN 网口 | `eth1`（USB RTL8153 那颗） |
| WAN 网口 | `eth0`（SoC GMAC） |
| 镜像格式 | SquashFS（只读 rootfs + overlay）与 Ext4 两种同时产出 |

---

## 🔌 烧录与首次启动

1. 下载 `*-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz`。
   **优先选 squashfs 版**：只读 rootfs + overlay 结构，支持"恢复出厂设置"
   （failsafe 里 `firstboot`，或 LuCI 的 Backup / Flash Firmware 页重置），
   配置弄坏了能回到初始状态。ext4 版空间利用率高，但没法这样重置。
2. **烧前检查分区表**（这一步能挡住无效镜像）：
   ```bash
   zcat xxx-sysupgrade.img.gz | head -c 2097152 | grep -a -o 'EFI PART'
   ```
   必须有输出。空输出说明镜像无效，不要烧。
3. 用 **balenaEtcher** 直接选 `.gz` 烧 TF 卡（不要用瑞芯微 SDDiskTool，它只接受带 `MEDIA:` 头的 `update.img`）。
4. 网线插 **LAN 口**，电脑手动设 `192.168.2.x/24`，上电等约 2 分钟，访问 `http://192.168.2.1`。
