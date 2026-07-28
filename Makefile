# MyOpenWRT - RK3566 编译 Makefile
# ========================================

include config.mk

.PHONY: all prepare kernel u-boot firmware plugins clean help

# 默认构建目标
all: firmware

# 创建必要构建目录
prepare:
	@mkdir -p $(SRC_DIR) $(BUILD_DIR) $(KERNEL_BUILD) $(UBOOT_BUILD)

# 编译内核
kernel: prepare $(KERNEL_CONFIG)
	@echo "===== 编译 RK3566 Linux 内核 ($(KERNEL_VERSION)) ====="
	@if [ ! -d "$(KERNEL_SRC)" ]; then \
		echo "[错误] 未在 $(KERNEL_SRC) 找到内核源码！"; \
		echo "请运行: mkdir -p src && wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$(KERNEL_VERSION).tar.xz -O src/linux-$(KERNEL_VERSION).tar.xz && tar -xf src/linux-$(KERNEL_VERSION).tar.xz -C src/"; \
		exit 1; \
	fi
	cp $(KERNEL_CONFIG) $(KERNEL_BUILD)/.config
	$(MAKE) -C $(KERNEL_SRC) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=$(KERNEL_BUILD) olddefconfig
	$(MAKE) -C $(KERNEL_SRC) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=$(KERNEL_BUILD) Image dtbs -j$$(nproc)

# 编译 U-Boot
u-boot: prepare $(UBOOT_CONFIG)
	@echo "===== 编译 RK3566 U-Boot ($(UBOOT_VERSION)) ====="
	@if [ ! -d "$(UBOOT_SRC)" ]; then \
		echo "[错误] 未在 $(UBOOT_SRC) 找到 U-Boot 源码！"; \
		echo "请运行: mkdir -p src && wget https://ftp.denx.de/pub/u-boot/u-boot-$(UBOOT_VERSION).tar.bz2 -O src/u-boot-$(UBOOT_VERSION).tar.bz2 && tar -xf src/u-boot-$(UBOOT_VERSION).tar.bz2 -C src/"; \
		exit 1; \
	fi
	cp $(UBOOT_CONFIG) $(UBOOT_BUILD)/.config
	$(MAKE) -C $(UBOOT_SRC) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=$(UBOOT_BUILD) olddefconfig
	$(MAKE) -C $(UBOOT_SRC) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) O=$(UBOOT_BUILD) -j$$(nproc)

# 编译插件与网络组件（LuCI + Firewall4 + MosDNS + OpenClash + OpenAppFilter + Tailscale + WireGuard）
plugins:
	@echo "===== 下载并构建自定义 OpenWrt 插件与包 ====="
	./compile-plugins.sh

# 编译固件（打包镜像）
firmware: kernel u-boot plugins
	@echo "===== 打包 RK3566 固件镜像 ====="
	./pack-image.sh
	@echo "固件生成完成：$(PROJECT_NAME)-$(VERSION).img.gz"

# 清理
clean:
	@echo "===== 清理构建文件 ====="
	rm -rf $(BUILD_DIR) $(SDK_DIR)
	rm -f $(PROJECT_NAME)-*.img $(PROJECT_NAME)-*.img.gz

# 显示帮助
help:
	@echo "MyOpenWRT 编译目标（适配 RK3566 / NanoPi R3S 1GB）："
	@echo "  make prepare   - 创建源码及编译输出目录"
	@echo "  make kernel    - 编译 ARM64 Linux 内核"
	@echo "  make u-boot    - 编译 U-Boot 引导程序"
	@echo "  make plugins   - 利用 OpenWrt SDK 构建用户指定插件 (MosDNS, OpenClash, Tailscale 等)"
	@echo "  make firmware  - 打包最终系统镜像 (.img.gz)"
	@echo "  make clean     - 清理构建文件"
