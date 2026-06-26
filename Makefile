# 猫头鹰 OS 构建 Makefile
# ============================

PROJECT    := maotouying-os
VERSION    := 0.1.0
CODENAME   := noble
ARCH       := amd64
DOCKER_IMG := maotouying-build
OUTPUT_DIR := output
BUILD_DIR  := build
CONFIGS_DIR := configs
SCRIPTS_DIR := scripts
PACKAGES_DIR := packages

.PHONY: help shell configs niri-deb dms-deb meta-deb bootstrap iso test clean

help: ## 显示帮助信息
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# ==================== Docker 构建环境 ====================

docker-build: ## 构建 Docker 镜像
	docker build -t $(DOCKER_IMG) -f docker/Dockerfile.build docker/

shell: docker-build ## 进入构建容器
	docker run -it --rm \
		-v $(PWD):/build \
		-v $(PWD)/$(OUTPUT_DIR):/build/$(OUTPUT_DIR) \
		--privileged \
		$(DOCKER_IMG) /bin/bash

# ==================== 配置文件捕获 ====================

configs: ## 从当前系统拷贝配置文件
	@echo "==> 捕获配置文件..."
	# niri 配置 (clean old, then copy fresh)
	rm -rf $(CONFIGS_DIR)/niri/dms/*
	rm -rf $(CONFIGS_DIR)/niri/scripts/*
	cp $$HOME/.config/niri/*.kdl $(CONFIGS_DIR)/niri/ 2>/dev/null || true
	cp $$HOME/.config/niri/dms/*.kdl $(CONFIGS_DIR)/niri/dms/ 2>/dev/null || true
	cp $$HOME/.config/niri/scripts/* $(CONFIGS_DIR)/niri/scripts/ 2>/dev/null || true
	# fuzzel 配置
	cp -r $$HOME/.config/fuzzel/* $(CONFIGS_DIR)/fuzzel/ 2>/dev/null || true
	# GTK 配置
	cp $$HOME/.config/gtk-3.0/settings.ini $(CONFIGS_DIR)/gtk/ 2>/dev/null || true
	# fcitx5 配置
	cp -r $$HOME/.config/fcitx5/* $(CONFIGS_DIR)/fcitx5/ 2>/dev/null || true
	# 自定义脚本
	cp $$HOME/.config/niri/scripts/niri-binds $(SCRIPTS_DIR)/ 2>/dev/null || true
	cp $$HOME/.config/niri/scripts/niri-force-kill-window $(SCRIPTS_DIR)/ 2>/dev/null || true
	cp $$HOME/.config/niri/scripts/niri-pick $(SCRIPTS_DIR)/ 2>/dev/null || true
	cp $$HOME/.config/niri/scripts/screenshot-sound.sh $(SCRIPTS_DIR)/ 2>/dev/null || true
	@echo "==> 配置文件捕获完成"
	@echo "==> 已拷贝:"
	@find $(CONFIGS_DIR) $(SCRIPTS_DIR) -type f | sort

# ==================== DEB 包构建 ====================

niri-deb: docker-build ## 在容器中编译 niri .deb 包
	@echo "==> 构建 niri .deb..."
	docker run --rm -v $(PWD):/build $(DOCKER_IMG) \
		bash -c "cd /build && packages/niri/build.sh"
	@echo "==> niri .deb 构建完成 → $(OUTPUT_DIR)/"

dms-deb: docker-build ## 在容器中编译 dms .deb 包
	@echo "==> 构建 dms .deb..."
	@echo "⚠️  需要先提供 dms 源码路径（编辑 packages/dms/build.sh）"
	# docker run --rm -v $(PWD):/build $(DOCKER_IMG) \
	#	bash -c "cd /build && packages/dms/build.sh"
	@echo "==> dms 构建已跳过（缺少源码）"

meta-deb: ## 构建 maotouying-desktop 元包
	@echo "==> 构建元包..."
	mkdir -p $(OUTPUT_DIR)/meta
	cd $(PACKAGES_DIR)/maotouying-desktop && \
		equivs-build control && \
		mv *.deb ../../$(OUTPUT_DIR)/meta/

# ==================== ISO 构建 ====================

bootstrap: ## debootstrap 构建 rootfs
	@echo "==> 开始 debootstrap..."
	@mkdir -p $(BUILD_DIR)/rootfs
	sudo debootstrap --arch=$(ARCH) $(CODENAME) $(BUILD_DIR)/rootfs https://mirrors.tuna.tsinghua.edu.cn/ubuntu/
	@echo "==> debootstrap 完成"

iso: ## 构建完整 ISO
	@echo "==> 构建猫头鹰 OS ISO..."
	@echo "TODO: 实现完整 ISO 构建流程"
	@echo "当前进度: M1 构建环境"

test: ## QEMU 测试 ISO
	@echo "==> 启动 QEMU 测试..."
	qemu-system-x86_64 \
		-m 4G \
		-enable-kvm \
		-cdrom $(OUTPUT_DIR)/$(PROJECT)-$(VERSION).iso \
		-boot d

clean: ## 清理构建产物
	rm -rf $(BUILD_DIR) $(OUTPUT_DIR)/*
	@echo "==> 已清理"
