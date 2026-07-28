#!/bin/bash
# MyOpenWRT - 插件与软件包编译脚本 (GitHub 高速源版)
# ========================================

set -e

# 取消 miniconda 的 CC/CXX 环境变量设置，使用 Ubuntu 原生 gcc / g++ / ld 编译工具链
unset CC CXX
export CC=gcc
export CXX=g++

# 彻底移除 PATH 中的 miniconda 环境
export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v 'miniconda' | tr '\n' ':' | sed 's/:$//')
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH

# 查找可用 zstd 解压工具
ZSTD_CMD="zstd"
if ! command -v zstd &>/dev/null; then
    if [ -x "$HOME/miniconda/bin/zstd" ]; then
        ZSTD_CMD="$HOME/miniconda/bin/zstd"
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SDK_VERSION="24.10.0"
SDK_FILENAME="openwrt-sdk-24.10.0-rockchip-armv8_gcc-13.3.0_musl.Linux-x86_64.tar.zst"
SDK_URL="https://downloads.openwrt.org/releases/${SDK_VERSION}/targets/rockchip/armv8/${SDK_FILENAME}"

NATIVE_SDK_DIR="$HOME/.openwrt-sdk-rk3566"
LINK_SDK_DIR="$SCRIPT_DIR/sdk"

echo "========================================"
echo "MyOpenWRT 插件编译脚本 v3.1 (GitHub 高速加速版)"
echo "支持功能：LuCI, SSH(Dropbear), 网页终端(ttyd), Firewall4+nftables, MosDNS, OpenClash, OpenAppFilter, Tailscale, WireGuard"
echo "排除功能：Docker, Samba/NFS/FTP, Aria2/qBittorrent, Python"
echo "========================================"

# 1. 下载并解压 OpenWrt v24.10.0 稳定版 SDK 至 Linux 原生文件系统
echo ""
echo "[1/4] 检查并准备 OpenWrt SDK (v$SDK_VERSION)..."
if [ ! -d "$NATIVE_SDK_DIR" ] || [ ! -f "$NATIVE_SDK_DIR/Makefile" ]; then
    rm -rf "$NATIVE_SDK_DIR"
    mkdir -p "$NATIVE_SDK_DIR"
    TMP_SDK_DIR=$(mktemp -d)
    echo "  正在下载 SDK ($SDK_FILENAME)..."
    wget --show-progress "$SDK_URL" -O "$TMP_SDK_DIR/sdk.tar.zst"
    echo "  正在解压 SDK 至 WSL ext4 原生文件系统..."
    $ZSTD_CMD -d "$TMP_SDK_DIR/sdk.tar.zst" -o "$TMP_SDK_DIR/sdk.tar"
    tar -xf "$TMP_SDK_DIR/sdk.tar" -C "$NATIVE_SDK_DIR" --strip-components=1
    rm -rf "$TMP_SDK_DIR"
    echo "  SDK 准备就绪"
else
    echo "  SDK 已存在于 Linux 原生路径 ($NATIVE_SDK_DIR)"
fi

# 建立软链接
rm -rf "$LINK_SDK_DIR"
ln -s "$NATIVE_SDK_DIR" "$LINK_SDK_DIR"

cd "$NATIVE_SDK_DIR"

# 2. 配置 GitHub 官方高速 Feeds 源 (替换慢速的 git.openwrt.org 索引)
echo ""
echo "[2/4] 配置 GitHub 官方高速分支 Feeds 源..."
cat << 'EOF' > feeds.conf.default
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
src-git luci https://github.com/openwrt/luci.git;openwrt-24.10
src-git routing https://github.com/openwrt-routing/packages.git;openwrt-24.10
src-git telephony https://github.com/openwrt/telephony.git;openwrt-24.10
src-git video https://github.com/openwrt/video.git;openwrt-24.10
EOF

./scripts/feeds update -a

# 3. 添加第三方插件仓库 (MosDNS, OpenClash, OpenAppFilter)
echo ""
echo "[3/4] 克隆第三方插件源码仓库..."

mkdir -p package/custom

# OpenClash
if [ ! -d "package/custom/luci-app-openclash" ]; then
    echo "  - 拉取 OpenClash 源码..."
    git clone --depth=1 https://github.com/vernesong/OpenClash.git package/custom/luci-app-openclash-tmp
    mv package/custom/luci-app-openclash-tmp/luci-app-openclash package/custom/luci-app-openclash
    rm -rf package/custom/luci-app-openclash-tmp
fi

# MosDNS
if [ ! -d "package/custom/luci-app-mosdns" ]; then
    echo "  - 拉取 MosDNS 源码..."
    git clone --depth=1 https://github.com/sbwml/luci-app-mosdns.git package/custom/luci-app-mosdns
fi

# OpenAppFilter (应用过滤)
if [ ! -d "package/custom/openappfilter" ]; then
    echo "  - 拉取 OpenAppFilter 源码..."
    git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/custom/openappfilter
fi

# 再次更新与安装 feed
./scripts/feeds install -a

# 4. 预配置软件包编译选项
echo ""
echo "[4/4] 生成 SDK 编译配置文件..."

cat << 'EOF' > .config
# 包含 SSH 服务与网页终端
CONFIG_PACKAGE_dropbear=y
CONFIG_PACKAGE_ttyd=y
CONFIG_PACKAGE_luci-app-ttyd=y

# 包含用户指定功能
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_luci-app-mosdns=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-oaf=y
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_kmod-wireguard=y
CONFIG_PACKAGE_wireguard-tools=y
CONFIG_PACKAGE_luci-proto-wireguard=y
EOF

make defconfig

echo ""
echo "========================================"
echo "✅ 插件 SDK 环境配置完成 (OpenWrt v${SDK_VERSION})！"
echo "========================================"
