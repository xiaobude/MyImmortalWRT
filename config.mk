# MyOpenWRT - RK3566 配置参数
# ========================================

# 基础项目信息
PROJECT_NAME := MyOpenWRT
VERSION := 1.0.0
BUILD_DATE := $(shell date +%Y-%m-%d)
BUILD_TIME := $(shell date +%H:%M:%S)
ARCHITECTURE := aarch64
TARGET_PLATFORM := rockchip-rk3568
DEVICE_NAME := rk3566-nanopi-r3s

# 项目工作目录配置
WORKSPACE_DIR := $(shell pwd)
SRC_DIR := $(WORKSPACE_DIR)/src
BUILD_DIR := $(WORKSPACE_DIR)/build

# 编译工具链配置
CROSS_COMPILE ?= aarch64-linux-gnu-
CC := $(CROSS_COMPILE)gcc
AR := $(CROSS_COMPILE)ar
OBJCOPY := $(CROSS_COMPILE)objcopy

# 内核与 U-Boot 源码路径
KERNEL_VERSION := 6.6.52
KERNEL_SRC := $(SRC_DIR)/linux-$(KERNEL_VERSION)
KERNEL_BUILD := $(BUILD_DIR)/kernel_build
KERNEL_CONFIG ?= $(WORKSPACE_DIR)/kernel.config

UBOOT_VERSION := 2023.10
UBOOT_SRC := $(SRC_DIR)/u-boot-$(UBOOT_VERSION)
UBOOT_BUILD := $(BUILD_DIR)/u-boot_build
UBOOT_CONFIG ?= $(WORKSPACE_DIR)/u-boot.config

# OpenWrt 稳定版 v24.10.0 SDK 配置
SDK_VERSION := 24.10.0
SDK_FILENAME := openwrt-sdk-24.10.0-rockchip-armv8_gcc-13.3.0_musl.Linux-x86_64.tar.zst
SDK_URL := https://downloads.openwrt.org/releases/$(SDK_VERSION)/targets/rockchip/armv8/$(SDK_FILENAME)
SDK_DIR := $(WORKSPACE_DIR)/sdk

# 包含的组件与插件列表（包含 SSH 服务与 Web 网页终端）
PACKAGES_ENABLE := \
    luci \
    dropbear \
    ttyd \
    luci-app-ttyd \
    firewall4 \
    nftables \
    kmod-nft-offload \
    mosdns \
    luci-app-mosdns \
    luci-app-openclash \
    openappfilter \
    luci-app-oaf \
    tailscale \
    luci-app-tailscale \
    kmod-wireguard \
    wireguard-tools \
    luci-proto-wireguard

# 排除的无用组件（保持精简，节省 1GB 内存与存储）
PACKAGES_DISABLE := \
    docker \
    dockerd \
    luci-app-dockerman \
    samba4 \
    ksmbd \
    luci-app-samba4 \
    nfs-kernel-server \
    vsftpd \
    aria2 \
    qbittorrent \
    transmission-daemon \
    python3 \
    python3-light

# 网络默认配置
DEFAULT_IPADDR ?= 192.168.1.1
DEFAULT_NETMASK ?= 255.255.255.0
DEFAULT_DNS ?= 114.114.114.114,223.5.5.5

# 根文件系统配置（适配 1GB 内存）
ROOTFS_TYPE := squashfs
JFFS2_PART_SIZE := 32M
UBIFS_PART_SIZE := 64M

# 编译参数
CFLAGS := -Wall -O2 -march=armv8-a+crc+crypto
LDFLAGS := -static-libgcc -static-libstdc++
