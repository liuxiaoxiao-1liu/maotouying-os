#!/bin/bash
# niri DEB 包构建脚本
# 在 Ubuntu 24.04 容器中运行
# 所有网络操作使用国内镜像源
set -e

NIRI_VERSION="26.04"
NIRI_REPO="https://github.com/YaLTeR/niri.git"
NIRI_MIRROR="https://ghproxy.net/https://github.com/YaLTeR/niri.git"
BUILD_DIR="/tmp/niri-build"
DEB_DIR="/build/output"
PKG_NAME="niri"
PKG_VERSION="${NIRI_VERSION}-1maotouying"

echo "==> Rust 版本..."
cargo --version && rustc --version

# Cargo 国内镜像（如果容器内还没配置）
mkdir -p $CARGO_HOME
if ! grep -q 'crates-io' $CARGO_HOME/config.toml 2>/dev/null; then
    echo '====> 配置 Cargo 清华镜像源...'
    cat > $CARGO_HOME/config.toml << 'CARGO_CFG'
[source.crates-io]
replace-with = "tuna"

[source.tuna]
registry = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
CARGO_CFG
fi

echo "==> 克隆 niri 源码（优先直连，失败则走代理）..."
rm -rf "$BUILD_DIR"
git clone --branch "v${NIRI_VERSION}" --depth 1 "$NIRI_REPO" "$BUILD_DIR" 2>/dev/null || \
git clone --branch "v${NIRI_VERSION}" --depth 1 "$NIRI_MIRROR" "$BUILD_DIR"

cd "$BUILD_DIR"

echo "==> 编译 niri (Release)..."
cargo build --release

echo "==> 准备打包目录..."
mkdir -p /tmp/niri-pkg/DEBIAN
mkdir -p /tmp/niri-pkg/usr/bin
mkdir -p /tmp/niri-pkg/usr/share/wayland-sessions
mkdir -p /tmp/niri-pkg/usr/share/niri

cp target/release/niri /tmp/niri-pkg/usr/bin/
cp -r resources/* /tmp/niri-pkg/usr/share/niri/ 2>/dev/null || true

# niri-session 入口脚本
cat > /tmp/niri-pkg/usr/bin/niri-session << 'NIRI_SESSION'
#!/bin/bash
export XMODIFIERS="@im=fcitx"
export QT_QPA_PLATFORMTHEME="gtk3"
export QT_QPA_PLATFORMTHEME_QT6="gtk3"
if command -v fcitx5 &> /dev/null; then
    fcitx5 -d &
fi
exec niri
NIRI_SESSION
chmod +x /tmp/niri-pkg/usr/bin/niri-session

# Wayland session 入口
cat > /tmp/niri-pkg/usr/share/wayland-sessions/niri.desktop << 'DESKTOP'
[Desktop Entry]
Name=Niri (猫头鹰)
Comment=A scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri;wayland;
DESKTOP

# DEB 控制文件
cat > /tmp/niri-pkg/DEBIAN/control << 'CONTROL'
Package: niri
Version: 26.04-1maotouying
Section: x11
Priority: optional
Architecture: amd64
Maintainer: Maotouying OS Team
Depends: libc6 (>= 2.38), libwayland-client0, libpipewire-0.3-0, libgbm1,
 libinput10, libxkbcommon0, libpixman-1-0, libpango-1.0-0, libdisplay-info2,
 libseat1, libcairo2, libglib2.0-0, libudev1, libdrm2,
 xdg-desktop-portal-impl, xdg-desktop-portal-gtk | xdg-desktop-portal-gnome
Description: Niri - A scrollable-tiling Wayland compositor
 Niri is a scrollable-tiling Wayland compositor that arranges windows
 in an infinitely scrollable horizontal strip.
 .
 Built for 猫头鹰 OS (Maotouying OS).
CONTROL

echo "==> 打包 .deb..."
mkdir -p "$DEB_DIR"
dpkg-deb --build /tmp/niri-pkg "$DEB_DIR/niri_${PKG_VERSION}_amd64.deb"

echo "==> 清理..."
rm -rf /tmp/niri-pkg /tmp/niri-build

echo "==> 猫头鹰 OS: niri .deb 构建完成!"
ls -lh "$DEB_DIR/niri_${PKG_VERSION}_amd64.deb"
