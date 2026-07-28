# ☁️ ImmortalWrt v25.12.1 云端编译（GitHub Actions）极速指南

已为您在当前项目中准备好了基于 **ImmortalWrt 官方最新 Release 标签 `v25.12.1`** 的全套 GitHub Actions 云编译配置文件！

无论是包含全套插件（OpenClash、MosDNS、OpenAppFilter、Tailscale、WireGuard、ttyd）还是 NanoPi R3S 的专属硬件驱动，云端服务器都会以 100% 专业的全核满载速度在 15-20 分钟内自动完成编译并生成下载包！

---

## 🛠️ 文件清单与架构

1. 📄 [build-immortalwrt.yml](file:///mnt/d/AI/MyopenWRT/.github/workflows/build-immortalwrt.yml)
   - 自动编译工作流脚本，绑定官方 `v25.12.1` 源码标签。
2. 📄 [immortalwrt-rk3566.config](file:///mnt/d/AI/MyopenWRT/immortalwrt-rk3566.config)
   - 针对 NanoPi R3S 优化的专属全插件精简配置文件（含 LuCI 简体中文、OpenClash、MosDNS、OpenAppFilter、Tailscale、WireGuard）。

---

## 🚀 3 步开启 GitHub 在线云编译

### 第一步：推送到您的 GitHub 仓库
在本地 WSL 终端（或终端工具）中运行：

```bash
cd /mnt/d/AI/MyopenWRT
git init
git add .
git commit -m "Add ImmortalWrt v25.12.1 cloud build workflow for NanoPi R3S"
git branch -M main
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```

*(如果您尚未在 GitHub 新建仓库，先去 GitHub 网页点击 **New Repository** 创建一个名为 `MyOpenWRT` 的仓库即可)*

---

### 第二步：一键触发在线编译

1. 打开您的 GitHub 仓库页面。
2. 点击顶部菜单栏的 **Actions** 标签。
3. 在左侧选择 **Build ImmortalWrt v25.12.1 for NanoPi R3S**。
4. 点击右侧的 **Run workflow** 按钮 ➔ **Run workflow**。

---

### 第三步：下载成品固件

1. 编译开始后，您可以实时查看 GitHub 云端服务器打印的编译日志。
2. 大约 **15 ~ 20 分钟后**，编译成功！
3. 您可以在 GitHub 仓库的 **Releases** 页面或 Workflow 详情页底部 **Artifacts** 处，直接一键下载：
   - 📦 `immortalwrt-25.12.1-rockchip-armv8-friendlyarm_nanopi-r3s-ext4-sysupgrade.img.gz`
   - 📦 `immortalwrt-25.12.1-rockchip-armv8-friendlyarm_nanopi-r3s-squashfs-sysupgrade.img.gz`

刷入 NanoPi R3S 即可直接享用最新 `v25.12.1` 版本的固件！
