#!/bin/bash
# 猫头鹰 OS rootfs + ISO 构建脚本
set -e

CODENAME=noble
ARCH=amd64
MIRROR="http://mirrors.tuna.tsinghua.edu.cn/ubuntu"
BUILD_DIR="/tmp/maotouying-build"
ROOTFS="$BUILD_DIR/rootfs"
ISODIR="$BUILD_DIR/iso"
OUTDIR="/build/output"
VERSION="0.1.0"

echo "=========================================="
echo "  猫头鹰 OS $VERSION ISO 构建"
echo "=========================================="

# 容器自身也需要 IPv4（debootstrap 用 wget）
echo 'prefer-family = IPv4' >> /etc/wgetrc

# Step 1
echo "==> [1/7] debootstrap Ubuntu $CODENAME..."
rm -rf "$ROOTFS"
mkdir -p "$ROOTFS"
debootstrap --arch=$ARCH --merged-usr "$CODENAME" "$ROOTFS" "$MIRROR"

# Step 2
echo "==> [2/7] 配置 chroot..."
mount --bind /dev "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount --bind /proc "$ROOTFS/proc"
mount --bind /sys "$ROOTFS/sys"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
mkdir -p "$ROOTFS/etc/apt/apt.conf.d"
echo 'Acquire::ForceIPv4 "true";' > "$ROOTFS/etc/apt/apt.conf.d/99force-ipv4"
rm -f "$ROOTFS/etc/apt/sources.list"
cat > "$ROOTFS/etc/apt/sources.list.d/ubuntu.sources" << 'APT'
Types: deb
URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
APT

# Step 3
echo "==> [3/7] chroot 安装软件..."
chroot "$ROOTFS" /bin/bash << 'INNER'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update

apt-get install -y --no-install-recommends \
    linux-image-generic initramfs-tools \
    systemd systemd-sysv grub-efi-amd64 grub-pc-bin \
    network-manager iwd ubuntu-standard

apt-get install -y --no-install-recommends \
    qt6-wayland qml6-module-qtquick \
    qml6-module-qtquick-controls qml6-module-qtquick-layouts \
    qml6-module-qtquick-window qml6-module-qtqml-workerscript \
    qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
    libqt6svg6 libqt6opengl6 libgl1 \
    libwayland-client0 libxkbcommon0 \
    pipewire wireplumber pipewire-pulse \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    policykit-1 accountsservice

# Firefox 从 Mozilla 官方 .deb 源安装
apt-get install -y --no-install-recommends software-properties-common
add-apt-repository -y ppa:mozillateam/ppa 2>&1 | tail -1
cat > /etc/apt/preferences.d/mozilla-firefox << MOZPIN
Package: firefox
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
MOZPIN
apt-get update -qq

apt-get install -y --no-install-recommends \
    fuzzel kitty fcitx5 fcitx5-chinese-addons \
    fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 \
    thunar xwayland fonts-cantarell firefox \
    breeze breeze-icon-theme breeze-cursor-theme \
    fonts-noto fonts-noto-cjk \
    wl-clipboard libnotify-bin x11-utils fzf vim

locale-gen zh_CN.UTF-8 en_US.UTF-8
update-locale LANG=zh_CN.UTF-8
# 首次启动时交互式创建用户
cat > /usr/local/sbin/maotouying-setup << 'SETUP'
#!/bin/bash
echo "===================================="
echo "  猫头鹰 OS - 首次设置"
echo "===================================="
read -p "用户名: " USERNAME
useradd -m -s /bin/bash "$USERNAME"
passwd "$USERNAME"
usermod -aG sudo,video,audio,input "$USERNAME"
cp -r /etc/skel/. "$(eval echo ~$USERNAME)/"
chown -R "$USERNAME:$USERNAME" "$(eval echo ~$USERNAME)/"
echo "设置完成。用 $USERNAME 登录后运行 niri-session 启动桌面。"
SETUP
chmod +x /usr/local/sbin/maotouying-setup

# 首次登录 tty1 时自动运行设置
cat >> /etc/profile << 'PROFILE'
if [ "$(tty)" = "/dev/tty1" ] && [ ! -f /etc/maotouying-done ]; then
    /usr/local/sbin/maotouying-setup
    sudo touch /etc/maotouying-done
fi
PROFILE
systemctl enable NetworkManager iwd
apt-get clean
rm -rf /var/lib/apt/lists/*
INNER

# Step 4
echo "==> [4/7] 安装自定义 DEB..."
cp "$OUTDIR"/*.deb "$ROOTFS/tmp/"
chroot "$ROOTFS" /bin/bash << 'INNER2'
# Step 3 清理了 apt 缓存，先恢复
apt-get update -qq
# 依次安装，遇到依赖问题 apt-get -f 修复
dpkg -i /tmp/niri_*.deb 2>&1 || true
dpkg -i /tmp/dms-shell_*.deb 2>&1 || true
apt-get install -f -y
dpkg -i /tmp/maotouying-config_*.deb 2>&1 || true
dpkg -i /tmp/maotouying-extras_*.deb 2>&1 || true
rm /tmp/*.deb
INNER2

# Step 5
echo "==> [5/7] initramfs..."
chroot "$ROOTFS" update-initramfs -u -k all 2>&1 || \
    chroot "$ROOTFS" /usr/sbin/update-initramfs -u -k all 2>&1 || \
    echo "initramfs skipped"

# Step 6
echo "==> [6/7] squashfs..."
umount -l "$ROOTFS/dev/pts" 2>/dev/null || true
umount -l "$ROOTFS/dev" 2>/dev/null || true
umount -l "$ROOTFS/proc" 2>/dev/null || true
umount -l "$ROOTFS/sys" 2>/dev/null || true
rm -rf "$ROOTFS/tmp/"* "$ROOTFS/run/"* 2>/dev/null || true

mkdir -p "$ISODIR/live" "$ISODIR/boot/grub"
KERNEL=$(ls "$ROOTFS/boot/vmlinuz-"* 2>/dev/null | head -1)
INITRD=$(ls "$ROOTFS/boot/initrd.img-"* 2>/dev/null | head -1)
[ -n "$KERNEL" ] && cp "$KERNEL" "$ISODIR/live/vmlinuz"
[ -n "$INITRD" ] && cp "$INITRD" "$ISODIR/live/initrd.img"

mksquashfs "$ROOTFS" "$ISODIR/live/filesystem.squashfs" \
    -comp zstd -Xcompression-level 3 -noappend

cat > "$ISODIR/boot/grub/grub.cfg" << 'GRUB'
set timeout=5
set default=0
menuentry "猫头鹰 OS Live" { linux /live/vmlinuz boot=live quiet splash; initrd /live/initrd.img; }
menuentry "猫头鹰 OS Live (safe)" { linux /live/vmlinuz boot=live nomodeset; initrd /live/initrd.img; }
GRUB

# Step 7
echo "==> [7/7] 打包 ISO..."
grub-mkrescue -o "$OUTDIR/maotouying-os-${VERSION}-amd64.iso" "$ISODIR" \
    --product-name="猫头鹰 OS" --product-version="$VERSION" 2>&1 | tail -3

ls -lh "$OUTDIR/maotouying-os-${VERSION}-amd64.iso"
echo "猫头鹰 OS ISO 构建完成!"
