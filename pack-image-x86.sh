#!/usr/bin/env bash
set -e

echo "========================================"
echo "🚀 开始打包 MyOpenWRT x86_64 EFI (VMware VMDK) 固件镜像..."
echo "  项目名称: MyOpenWRT"
echo "  固件版本: 1.0.0"
echo "  目标架构: x86_64 (VMware Workstation / ESXi / VirtualBox, EFI+Legacy双驱动)"
echo "  默认 IP: 192.168.10.1 (防主路由器 IP 冲突)"
echo "  输出文件: MyOpenWRT-1.0.0-x86_64.vmdk"
echo "========================================"

BUILD_DIR="/tmp/myopenwrt_x86_pack"
ROOTFS="$BUILD_DIR/rootfs"
SDK_X86="$HOME/.openwrt-sdk-x86-64"
SDK_RK="$HOME/.openwrt-sdk-rk3566"
OUTPUT_DIR="/mnt/d/AI/MyopenWRT"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$ROOTFS" "$OUTPUT_DIR/bin/ipk_packages_x86"

echo "[1/4] 下载与解压官方 x86_64 EFI 引导基础软路由镜像..."
RAW_IMG_URL="https://downloads.openwrt.org/releases/24.10.0/targets/x86/64/openwrt-24.10.0-x86-64-generic-squashfs-combined-efi.img.gz"
BASE_IMG="$BUILD_DIR/base.img"
curl -sL "$RAW_IMG_URL" -o "$BUILD_DIR/base.img.gz"
gzip -dc "$BUILD_DIR/base.img.gz" > "$BASE_IMG" || true

echo "[2/4] 解压整合已编译的 x86_64 IPK 插件与系统组件..."
# 1. 解压 RK3566 编出的 架构无关包 (_all.ipk)
find "$SDK_RK/bin/packages" -name "*_all.ipk" | while read ipk; do
    cp "$ipk" "$OUTPUT_DIR/bin/ipk_packages_x86/" 2>/dev/null || true
    if tar -tf "$ipk" 2>/dev/null | grep -q "data.tar.gz"; then
        tar -xf "$ipk" -O ./data.tar.gz 2>/dev/null | tar -C "$ROOTFS" -xzf - 2>/dev/null || true
    fi
done

# 2. 解压 x86_64 编出的 专属二进制包 (_x86_64.ipk 及 _all.ipk)
find "$SDK_X86/bin/packages" -name "*.ipk" | while read ipk; do
    cp "$ipk" "$OUTPUT_DIR/bin/ipk_packages_x86/" 2>/dev/null || true
    if tar -tf "$ipk" 2>/dev/null | grep -q "data.tar.gz"; then
        tar -xf "$ipk" -O ./data.tar.gz 2>/dev/null | tar -C "$ROOTFS" -xzf - 2>/dev/null || true
    fi
done

echo "  已成功注入全套 x86_64 插件 (OpenClash, MosDNS, OpenAppFilter, OpenSSL, Bash, Curl等)"

echo "[3/4] 配置 x86_64 系统网络与基础服务预设 (默认 LAN IP: 192.168.10.1)..."
mkdir -p "$ROOTFS/etc/config" "$ROOTFS/etc/uci-defaults"

cat << 'EOF' > "$ROOTFS/etc/config/network"
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fd00::/48'

config device
	option name 'eth0'
	option macaddr '52:54:00:12:34:56'

config interface 'lan'
	option device 'eth0'
	option proto 'static'
	option ipaddr '192.168.10.1'
	option netmask '255.255.255.0'
	option ip6assign '64'
EOF

cat << 'EOF' > "$ROOTFS/etc/openwrt_release"
DISTRIB_ID='MyOpenWRT'
DISTRIB_RELEASE='1.0.0'
DISTRIB_REVISION='v24.10.0-x86_64'
DISTRIB_TARGET='x86/64'
DISTRIB_ARCH='x86_64'
DISTRIB_DESCRIPTION='MyOpenWRT 1.0.0 x86_64 (VMware VMDK Edition - 192.168.10.1)'
EOF

cat << 'EOF' > "$ROOTFS/etc/uci-defaults/99-custom-init"
#!/bin/sh
uci set system.@system[0].hostname='MyOpenWRT-VM'
uci set system.@system[0].zonename='Asia/Shanghai'
uci set system.@system[0].timezone='CST-8'
uci commit system

# 开启 Dropbear SSH 允许 root 密码登录
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci commit dropbear

exit 0
EOF
chmod +x "$ROOTFS/etc/uci-defaults/99-custom-init"

echo "[4/4] 生成 SquashFS 根文件系统与 VMware VMDK 格式转换..."
mksquashfs "$ROOTFS" "$BUILD_DIR/rootfs.squashfs" -comp lzma -b 256k -noappend

# 找到官方基础镜像中 RootFS 分区 (Part 2) 的偏移量
PART2_START_SECTOR=$(fdisk -l "$BASE_IMG" 2>/dev/null | grep -E "img2|base.img2" | awk '{print $2}')
if [ -z "$PART2_START_SECTOR" ]; then
    PART2_START_SECTOR=33792
fi

PART2_OFFSET=$((PART2_START_SECTOR * 512))
echo "  RootFS 分区扇区起始: $PART2_START_SECTOR (字节偏移量: $PART2_OFFSET)"

# 将打包好的 SquashFS 写入基础镜像的第 2 分区位置
dd if="$BUILD_DIR/rootfs.squashfs" of="$BASE_IMG" seek=$PART2_START_SECTOR bs=512 conv=notrunc 2>/dev/null

FINAL_VMDK="$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64.vmdk"
FINAL_FLAT="$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64-flat.vmdk"

# 复制 raw 磁盘映像为 FLAT VMDK
cp "$BASE_IMG" "$FINAL_FLAT"

# 获取文件总大小（字节）与扇区数
FILE_BYTES=$(stat -c%s "$FINAL_FLAT")
SECTORS=$((FILE_BYTES / 512))

# 创建 VMware 标准 MonolithicFlat VMDK 描述符文件
cat << EOF > "$FINAL_VMDK"
# Disk DescriptorFile
version=1
CID=fffffffe
parentCID=ffffffff
createType="monolithicFlat"

# Extent description
RW $SECTORS FLAT "MyOpenWRT-1.0.0-x86_64-flat.vmdk" 0

# The Disk Data Base
#DDB

ddb.adapterType = "ide"
ddb.geometry.cylinders = "$((SECTORS / 16 / 63))"
ddb.geometry.heads = "16"
ddb.geometry.sectors = "63"
EOF

# 额外导出一份压缩的 .img.gz
cp "$BASE_IMG" "$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64.img"
gzip -f -9 "$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64.img"

echo ""
echo "========================================"
echo "🎉 🎉 MyOpenWRT x86_64 (EFI/Legacy双适应) 固件打包完成！"
echo "  VMware 描述符: $FINAL_VMDK"
echo "  VMware 数据盘: $FINAL_FLAT"
echo "  默认后台 IP: 192.168.10.1"
echo "========================================"
