#!/bin/bash
# MyOpenWRT - 自动化构建主脚本
# ========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 读取配置
if [ -f "config.mk" ]; then
    PROJECT_NAME=$(grep "^PROJECT_NAME :=" config.mk | awk '{print $3}')
    VERSION=$(grep "^VERSION :=" config.mk | awk '{print $3}')
    KERNEL_VERSION=$(grep "^KERNEL_VERSION :=" config.mk | awk '{print $3}')
    UBOOT_VERSION=$(grep "^UBOOT_VERSION :=" config.mk | awk '{print $3}')
    CROSS_COMPILE=$(grep "^CROSS_COMPILE ?=" config.mk | awk '{print $3}')
fi

PROJECT_NAME="${PROJECT_NAME:-MyOpenWRT}"
VERSION="${VERSION:-1.0.0}"
KERNEL_VERSION="${KERNEL_VERSION:-6.6.52}"
UBOOT_VERSION="${UBOOT_VERSION:-2023.10}"
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-gnu-}"

echo "========================================"
echo "MyOpenWRT 构建脚本"
echo "目标平台: RK3566 / NanoPi R3S (ARM64)"
echo "内核版本: Linux $KERNEL_VERSION"
echo "U-Boot : $UBOOT_VERSION"
echo "构建时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

# 1. 检查交叉编译器
if ! command -v "${CROSS_COMPILE}gcc" &> /dev/null; then
    echo "[错误] 未检测到 ${CROSS_COMPILE}gcc 交叉编译工具链！"
    echo "请先安装：sudo apt update && sudo apt install -y gcc-aarch64-linux-gnu"
    exit 1
fi

# 2. 准备组件与插件
echo ""
echo "----------------------------------------"
echo "步骤 1/3: 准备 OpenWrt SDK 与插件..."
echo "----------------------------------------"
./compile-plugins.sh

# 3. 检查内核源码
echo ""
echo "----------------------------------------"
echo "步骤 2/3: 检查内核与 U-Boot 源码..."
echo "----------------------------------------"
if [ ! -d "src/linux-$KERNEL_VERSION" ] || [ ! -d "src/u-boot-$UBOOT_VERSION" ]; then
    echo "[提示] 检测到 src/ 目录下尚未准备完整的 Linux 内核或 U-Boot 源码。"
    echo "如需从零编译内核与 U-Boot，请先下载源码至 src/ 目录。"
    echo "详细步骤见 README.md。"
fi

# 4. 打包镜像
echo ""
echo "----------------------------------------"
echo "步骤 3/3: 执行打包固件流程..."
echo "----------------------------------------"
make prepare
./pack-image.sh

echo ""
echo "========================================"
echo "✅ 构建辅助脚本运行完毕！"
echo "========================================"
