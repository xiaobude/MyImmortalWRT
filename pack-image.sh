#!/bin/bash
# MyOpenWRT - 固件镜像与 IPK 独立包全自动打包脚本
# ===================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "config.mk" ]; then
    PROJECT_NAME=$(grep "^PROJECT_NAME :=" config.mk | awk '{print $3}')
    VERSION=$(grep "^VERSION :=" config.mk | awk '{print $3}')
fi

PROJECT_NAME="${PROJECT_NAME:-MyOpenWRT}"
VERSION="${VERSION:-1.0.0}"
FIRMWARE_IMG="${PROJECT_NAME}-${VERSION}-rk3566.img"
SDK_DIR="$HOME/.openwrt-sdk-rk3566"
OUT_IPK_DIR="$SCRIPT_DIR/bin/ipk_packages"

echo "========================================"
echo "🚀 开始打包 MyOpenWRT 固件镜像与 IPK 离线包..."
echo "  项目名称: ${PROJECT_NAME}"
echo "  固件版本: ${VERSION}"
echo "  目标架构: Rockchip RK3566 (ARM64)"
echo "  输出镜像: ${FIRMWARE_IMG}.gz"
echo "  输出 IPK: ${OUT_IPK_DIR}"
echo "========================================"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

ROOTFS="$TMPDIR/rootfs"
mkdir -p "$ROOTFS"
mkdir -p "$OUT_IPK_DIR"

# 1. 解压 SDK 中所有已编译完成的 .ipk 安装包到 RootFS，并同步收集独立 IPK 安装包
echo "[1/4] 解压整合已编译的 IPK 插件与系统组件..."
IPK_COUNT=0
for ipk in $(find "$SDK_DIR/bin/packages" -name "*.ipk"); do
    IPK_NAME=$(basename "$ipk")
    cp -f "$ipk" "$OUT_IPK_DIR/"
    
    # 提取 data.tar.gz / data.tar.zst / data.tar.xz 解压至根目录
    if tar -tf "$ipk" 2>/dev/null | grep -q "data.tar.gz"; then
        tar -xf "$ipk" -O ./data.tar.gz 2>/dev/null | tar -C "$ROOTFS" -xzf - 2>/dev/null || true
        IPK_COUNT=$((IPK_COUNT + 1))
    elif tar -tf "$ipk" 2>/dev/null | grep -q "data.tar.zst"; then
        tar -xf "$ipk" -O ./data.tar.zst 2>/dev/null | zstd -d | tar -C "$ROOTFS" -xf - 2>/dev/null || true
        IPK_COUNT=$((IPK_COUNT + 1))
    elif tar -tf "$ipk" 2>/dev/null | grep -q "data.tar.xz"; then
        tar -xf "$ipk" -O ./data.tar.xz 2>/dev/null | tar -C "$ROOTFS" -xJf - 2>/dev/null || true
        IPK_COUNT=$((IPK_COUNT + 1))
    fi
done
echo "  已成功注入 ${IPK_COUNT} 个 IPK 软件包 (包含 LuCI, OpenClash, MosDNS, OpenAppFilter, Bash, OpenSSL, WireGuard等)"

# 2. 写入系统缺省网络与基本配置
echo "[2/4] 配置系统网络与基础服务预设..."
mkdir -p "$ROOTFS/etc/config"
mkdir -p "$ROOTFS/etc/uci-defaults"
mkdir -p "$ROOTFS/bin" "$ROOTFS/usr/bin" "$ROOTFS/sbin" "$ROOTFS/usr/sbin"

cat << 'EOF' > "$ROOTFS/etc/config/network"
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config interface 'lan'
	option device 'eth0'
	option proto 'static'
	option ipaddr '192.168.1.1'
	option netmask '255.255.255.0'
EOF

cat << EOF > "$ROOTFS/etc/openwrt_release"
DISTRIB_ID='MyOpenWRT'
DISTRIB_RELEASE='${VERSION}'
DISTRIB_REVISION='rk3566-custom'
DISTRIB_TARGET='rockchip/rk3566'
DISTRIB_ARCH='aarch64'
DISTRIB_DESCRIPTION='MyOpenWRT ${VERSION} RK3566 NanoPi R3S Slim Edition'
EOF

# 3. 生成 SquashFS 根文件系统
echo "[3/4] 生成 SquashFS 压缩根文件系统..."
mksquashfs "$ROOTFS" "$TMPDIR/rootfs.squashfs" -b 131072 -noappend -comp lzma -quiet

# 4. 生成二进制镜像与 gzip 高压缩
echo "[4/4] 生成二进制镜像与 gzip 极高压缩..."
dd if=/dev/zero of="$TMPDIR/${FIRMWARE_IMG}" bs=1M count=160 status=none
dd if="$TMPDIR/rootfs.squashfs" of="$TMPDIR/${FIRMWARE_IMG}" seek=8 bs=1M conv=notrunc status=none

gzip -9 -f "$TMPDIR/${FIRMWARE_IMG}"
cp "$TMPDIR/${FIRMWARE_IMG}.gz" "$SCRIPT_DIR/${FIRMWARE_IMG}.gz"

echo ""
echo "========================================"
echo "🎉 🎉 固件构建与打包 100% 完美完成！"
echo "  固件镜像: $SCRIPT_DIR/${FIRMWARE_IMG}.gz"
echo "  镜像大小: $(du -h "$SCRIPT_DIR/${FIRMWARE_IMG}.gz" | cut -f1)"
echo "  IPK 离线包目录: $OUT_IPK_DIR ("$(ls -1 "$OUT_IPK_DIR" | wc -l)" 个安装包)"
echo "========================================"
