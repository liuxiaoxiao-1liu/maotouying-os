#!/bin/bash
# dms DEB 包构建脚本 (占位)
# 需要用户提供 dms 源码路径后补充
#
# 已知信息:
#   dms - 基于 quickshell 的 niri 桌面面板
#   quickshell - Qt6 QML shell 框架
#   dsearch - dms 配套搜索服务
#
# 使用方法:
#   1. 将 dms 和 quickshell 源码放到 packages/dms/src/
#   2. 修改下方的 SRC_DIR 路径
#   3. 在 Docker 容器中运行: bash packages/dms/build.sh

set -e

DMS_SRC="packages/dms/src/dms"
QUICKSHELL_SRC="packages/dms/src/quickshell"
DEB_DIR="/build/output"

echo "==> 检查 dms 源码..."
if [ ! -d "$DMS_SRC" ]; then
    echo "❌ 错误: 找不到 dms 源码目录: $DMS_SRC"
    echo "   请将 dms 源码放到该目录后重试"
    echo ""
    echo "   如果 dms 源码在其他位置, 请设置环境变量:"
    echo "   DMS_SRC=/path/to/dms bash packages/dms/build.sh"
    exit 1
fi

echo "==> 安装编译依赖..."
apt-get update
apt-get install -y \
    cmake qt6-base-dev qt6-declarative-dev \
    qt6-tools-dev qt6-tools-dev-tools \
    libqt6svg6-dev libqt6opengl6-dev \
    libwayland-dev wayland-protocols \
    pkg-config

echo "==> 编译 quickshell..."
if [ -d "$QUICKSHELL_SRC" ]; then
    cd "$QUICKSHELL_SRC"
    mkdir -p build && cd build
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr
    make -j$(nproc)
    make install
    cd /
fi

echo "==> 编译 dms..."
cd "$DMS_SRC"
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)

echo "==> 打包 dms .deb..."
mkdir -p /tmp/dms-pkg/DEBIAN
mkdir -p /tmp/dms-pkg/usr/bin
mkdir -p /tmp/dms-pkg/usr/share/applications

# 复制二进制
cp dms /tmp/dms-pkg/usr/bin/ 2>/dev/null || true
cp dsearch /tmp/dms-pkg/usr/bin/ 2>/dev/null || true

cat > /tmp/dms-pkg/DEBIAN/control << 'CONTROL'
Package: dms
Version: 0.1.0-1maotouying
Section: x11
Priority: optional
Architecture: amd64
Maintainer: Maotouying OS Team
Depends: quickshell, qt6-base, qt6-declarative, libwayland-client0
Description: Desktop Management Shell for Niri
 dms is a custom desktop panel/management shell for the Niri
 scrollable-tiling Wayland compositor, powered by Quickshell.
CONTROL

mkdir -p "$DEB_DIR"
dpkg-deb --build /tmp/dms-pkg "$DEB_DIR/dms_0.1.0-1maotouying_amd64.deb"

echo "==> dms .deb 构建完成!"
