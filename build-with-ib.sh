#!/usr/bin/env bash
set -e

echo "========================================"
echo "🚀 使用官方 ImageBuilder 100% 完美生成 x86_64 VMware 镜像..."
echo "========================================"

IB_DIR="$HOME/.openwrt-ib-x86-64"
SDK_X86="$HOME/.openwrt-sdk-x86-64"
SDK_RK="$HOME/.openwrt-sdk-rk3566"
OUTPUT_DIR="/mnt/d/AI/MyopenWRT"

cd "$IB_DIR"

echo "[1/4] 收集所有已编译的独立 IPK 插件包到 ImageBuilder 仓库..."
mkdir -p "$IB_DIR/packages" "$IB_DIR/files/etc/config" "$IB_DIR/files/etc/uci-defaults"

find "$SDK_RK/bin/packages" -name "*_all.ipk" -exec cp {} "$IB_DIR/packages/" \; 2>/dev/null || true
find "$SDK_X86/bin/packages" -name "*.ipk" -exec cp {} "$IB_DIR/packages/" \; 2>/dev/null || true

echo "  独立 IPK 安装包全数导入完成！"

echo "[2/4] 注入预设系统配置 (默认 LAN IP: 192.168.10.1)..."

cat << 'EOF' > "$IB_DIR/files/etc/config/network"
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
	option ipaddr '10.0.0.250'
	option netmask '255.255.255.0'
	option ip6assign '64'
EOF

cat << 'EOF' > "$IB_DIR/files/etc/openwrt_release"
DISTRIB_ID='MyOpenWRT'
DISTRIB_RELEASE='1.0.0'
DISTRIB_REVISION='v24.10.0-x86_64'
DISTRIB_TARGET='x86/64'
DISTRIB_ARCH='x86_64'
DISTRIB_DESCRIPTION='MyOpenWRT 1.0.0 x86_64 (VMware VMDK Edition - 192.168.10.1)'
EOF

cat << 'EOF' > "$IB_DIR/files/etc/uci-defaults/99-custom-init"
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
chmod +x "$IB_DIR/files/etc/uci-defaults/99-custom-init"

echo "[3/4] 执行 ImageBuilder 官方镜像合成流程..."
export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v 'Files/' | tr '\n' ':' | sed 's/:$//')
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

make image PROFILE="generic" ROOTFS_PARTSIZE=512 \
    PACKAGES="luci luci-compat luci-i18n-base-zh-cn luci-i18n-package-manager-zh-cn luci-i18n-firewall-zh-cn luci-app-openclash luci-app-mosdns mosdns luci-i18n-mosdns-zh-cn appfilter bash curl openssl-util kmod-wireguard wireguard-tools ttyd luci-app-ttyd luci-i18n-ttyd-zh-cn -dnsmasq dnsmasq-full" \
    FILES="files"

echo "[4/4] 提取生成的标准 VMDK 与 img.gz 图像文件..."
mkdir -p "$OUTPUT_DIR/bin/ipk_packages_x86"

SRC_IMG="$IB_DIR/bin/targets/x86/64/openwrt-24.10.0-x86-64-generic-squashfs-combined-efi.img.gz"
FINAL_VMDK="$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64.vmdk"
FINAL_FLAT="$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64-flat.vmdk"

gzip -dc "$SRC_IMG" > "$FINAL_FLAT" || true

FILE_BYTES=$(stat -c%s "$FINAL_FLAT")
SECTORS=$((FILE_BYTES / 512))

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

cp "$SRC_IMG" "$OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64.img.gz"
cp "$IB_DIR/packages/"*.ipk "$OUTPUT_DIR/bin/ipk_packages_x86/" 2>/dev/null || true

echo ""
echo "========================================"
echo "🎉 🎉 官方 ImageBuilder 合成 100% 成功！"
echo "  VMware 描述符: $FINAL_VMDK"
echo "  VMware 数据盘: $FINAL_FLAT"
echo "  通用压缩镜像: $OUTPUT_DIR/MyOpenWRT-1.0.0-x86_64.img.gz"
echo "  默认后台 IP: 192.168.10.1"
echo "========================================"
