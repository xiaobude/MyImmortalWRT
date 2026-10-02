# ☁️ 云端编译指南（GitHub Actions）

固件由 GitHub Actions 上的 **完整 ImmortalWrt 源码树** 编译。本地无需交叉工具链、无需 WSL、无需下载 SDK。

产物是官方镜像结构（GPT 分区表 + U-Boot/idbloader + 内核 FIT + rootfs），TF 卡可直接启动。

---

## 🛠️ 文件清单

1. `.github/workflows/build-immortalwrt.yml`
   - 构建工作流：装依赖 → clone 源码 → 装 feeds → 套 `.config` 与 `files/` 覆盖 → **校验板型与包符号** → 编译 → **校验分区表** → 上传 Artifacts 与 Release
2. `immortalwrt-rk3328.config`
   - 板型（RK3328 / NanoPi R2S）与软件包选择
3. `files/etc/config/network`
   - 根文件系统覆盖：LAN=`eth1`、WAN=`eth0`、IP `192.168.2.1`

编译版本在 workflow 的 `env.REPO_TAG`（当前 `v25.12.1`）。

---

## 🚀 3 步开启云编译

### 第一步：推送到 GitHub

首次使用需先允许 git 操作该目录，并解决一次所有权告警：

```bash
git config --global --add safe.directory G:/MyopenWRT
cd /g/MyopenWRT
git add -A
git commit -m "Adapt for RK3328 / NanoPi R2S"
git branch -M main
git remote add origin https://github.com/你的用户名/MyOpenWRT.git
git push -u origin main
```

### 第二步：触发编译

仓库 **Actions** → 左侧选 **Build ImmortalWrt Streamlined for NanoPi R2S (RK3328)** → **Run workflow** → **Run workflow**。

RK3328 目标需要编译内核与全部软件包，实际耗时约 **30～60 分钟**（视 Runner 负载）。

### 第三步：下载成品固件

构建成功后，Artifacts 或 Releases 里得到：

- `immortalwrt-<版本>-rockchip-armv8-friendlyarm_nanopi-r2s-squashfs-sysupgrade.img.gz` ← TF 卡推荐
- `immortalwrt-<版本>-rockchip-armv8-friendlyarm_nanopi-r2s-ext4-sysupgrade.img.gz` ← 空间利用率高，但无法用 overlay 重置
- 同目录下的 `.manifest` / `config.buildinfo` / `sha256sums` 用于核对实际打进去的包

**balenaEtcher 直接选 `.gz` 烧录**，不要解压、不要用瑞芯微 SDDiskTool（它只接受带 `MEDIA:` 头的 `update.img`）。

---

## 🔍 构建里内置的两道防呆

工作流会在编译后立即失败，而不是把不可用的镜像推给你：

1. **板型检查**：`make defconfig` 后校验 `.config` 里 `CONFIG_TARGET_rockchip_armv8_DEVICE_friendlyarm_nanopi-r2s=y` 仍然存在。若源码树改了符号名，构建会直接报错而不是悄悄编成别的板子。
2. **分区表检查**：对每个产出的 `.img.gz` 检查前 2 MB 是否含 `EFI PART`（GPT 头）。

---

---

## ✅ 已对 v25.12.1 源码树核实的事实

| 项 | 结论 |
|---|---|
| `REPO_TAG: v25.12.1` | 存在（tags 里另有 v25.12.0 / v25.12.2） |
| 板型符号 | `friendlyarm_nanopi-r2s` 存在，继承 `Device/rk3328`，`DEVICE_PACKAGES := kmod-usb-net-rtl8152` → `eth1` 那颗 RTL8153 会被自动打进固件 |
| 25.x 目录结构变化 | 子目标文件已从 `armv8/Makefile` 改名 `armv8/target.mk`，板型定义移到 `target/linux/rockchip/image/armv8.mk` |
| 产物命名 | `IMAGES := sysupgrade.img.gz`，即 **没有** 单独的 `-sdcard.img.gz`；`*-squashfs-sysupgrade.img.gz` 本身就是含 GPT + FAT boot 分区 + u-boot-rockchip.bin 的完整卡图 |
| OpenClash | 由 `immortalwrt/luci` feed 直接提供 `luci-app-openclash`（v0.47.075），**无需** clone vernesong/OpenClash |
| tailscale | `immortalwrt/packages` 提供 `tailscale`（v1.98.3）；但 luci feed 里 **没有** `luci-app-tailscale`，所以配置里不带它 |
| ttyd | `immortalwrt/packages` 的 `utils/ttyd`；`luci-app-ttyd` 在 luci feed ✓ |
| MosDNS / OpenAppFilter | `mosdns` 在 packages feed，但 `luci-app-mosdns`、`luci-app-oaf` 都不在这两个 feed 里 → 要加必须 clone sbwml / destan19 仓库 |

---

## ⚠️ 常见失败与处理

| 现象 | 处理 |
|---|---|
| `Clone ImmortalWrt Source Code` 报 `Remote branch ... not found` | `REPO_TAG` 在该版本不存在，改成 ImmortalWrt releases 页确认存在的 tag |
| `板型检查` 或 `包符号检查` 失败 | 升级/更换 `REPO_TAG` 后符号名可能变动；去 `target/linux/rockchip/image/armv8.mk` 与对应 feed 仓库查真实名字，同步改 `immortalwrt-rk3328.config` 与 `env.DEVICE_PROFILE` |
| `分区表检查` 失败 | 说明产出的不是卡图，检查 `CONFIG_TARGET_*` 是否被 defconfig 改写，把该步日志贴出来 |
| 磁盘不足 | 已清理 dotnet/android/ghc/docker；仍不够就删掉不必要的 `CONFIG_PACKAGE_*` |
| 想要 OpenClash 最新版而非 feed 里的 0.47.075 | 在 `Load Feeds` 步骤后加：`git clone --depth=1 https://github.com/vernesong/OpenClash.git /tmp/oc && mkdir -p package/custom && cp -r /tmp/oc/luci-app-openclash package/custom/`（注意必须取子目录，clone 整仓库当包目录会被静默忽略） |

构建失败时把 Actions 日志里报错那一段完整贴出来，可据此定位。
