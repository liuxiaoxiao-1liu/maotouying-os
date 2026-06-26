#!/bin/bash
# 从本地 rootfs 继续构建，利用已有缓存
set -e
R="/home/liuxiaoxiao/文件/操作系统/build/rootfs"
O="/home/liuxiaoxiao/文件/操作系统/output"

echo "==> 配置 chroot..."
mount --bind /dev "$R/dev"
mount --bind /proc "$R/proc"
mount --bind /sys "$R/sys"
cp /etc/resolv.conf "$R/etc/resolv.conf"
mkdir -p "$R/etc/apt/apt.conf.d"
echo 'Acquire::ForceIPv4 "true";' > "$R/etc/apt/apt.conf.d/99force-ipv4"

# apt 源
cat > "$R/etc/apt/sources.list.d/ubuntu.sources" << 'APT'
Types: deb
URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
APT

echo "==> apt update..."
chroot "$R" apt-get update -qq

echo "==> 安装内核+系统..."
chroot "$R" apt-get install -y --no-install-recommends \
    linux-image-generic initramfs-tools \
    systemd systemd-sysv grub-efi-amd64 grub-pc-bin \
    network-manager iwd bluez bluez-tools ubuntu-standard

echo "==> 安装桌面运行时..."
chroot "$R" apt-get install -y --no-install-recommends \
    qt6-wayland qml6-module-qtquick \
    qml6-module-qtquick-controls qml6-module-qtquick-layouts \
    qml6-module-qtquick-window qml6-module-qtqml-workerscript \
    qml6-module-qtquick-dialogs qml6-module-qtquick-templates \
    libqt6svg6 libqt6opengl6 libgl1 \
    libwayland-client0 libxkbcommon0 \
    pipewire wireplumber pipewire-pulse \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome \
    policykit-1 accountsservice

echo "==> 安装桌面应用..."
chroot "$R" apt-get install -y --no-install-recommends \
    fuzzel kitty fcitx5 fcitx5-chinese-addons \
    fcitx5-frontend-gtk3 fcitx5-frontend-gtk4 fcitx5-frontend-qt5 \
    thunar \
    breeze breeze-icon-theme breeze-cursor-theme \
    fonts-noto fonts-noto-cjk \
    wl-clipboard libnotify-bin x11-utils fzf vim \
	    slurp pavucontrol fcitx5-config-qt fish cliphist

echo "==> 设置系统..."
chroot "$R" locale-gen zh_CN.UTF-8 en_US.UTF-8
chroot "$R" update-locale LANG=zh_CN.UTF-8

# 首次启动设置
echo 'root:maotouying' | chroot "$R" chpasswd
cat > "$R/usr/local/sbin/maotouying-setup" << 'SETUP'
#!/bin/bash
echo "===================================="
echo "  猫头鹰 OS - 首次设置"
echo "===================================="
read -p "  用户名: " USERNAME
useradd -m -s /bin/bash "$USERNAME"
passwd "$USERNAME"
usermod -aG sudo,video,audio,input "$USERNAME"
cp -r /etc/skel/. "$(eval echo ~$USERNAME)/"
chown -R "$USERNAME:$USERNAME" "$(eval echo ~$USERNAME)/"
echo "  设置完成！用 $USERNAME 登录后运行 niri-session 启动桌面。"
touch /etc/maotouying-done
rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
SETUP
chmod +x "$R/usr/local/sbin/maotouying-setup"

cat > "$R/root/.bash_profile" << 'ROOTPROF'
if [ ! -f /etc/maotouying-done ]; then
    /usr/local/sbin/maotouying-setup
else
    echo "首次设置已完成，请用你的用户名登录。"
    exit 1
fi
ROOTPROF

mkdir -p "$R/etc/systemd/system/getty@tty1.service.d"
cat > "$R/etc/systemd/system/getty@tty1.service.d/override.conf" << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
AUTOLOGIN

chroot "$R" systemctl enable NetworkManager iwd bluetooth

echo "==> 安装自定义 DEB..."
cp "$O"/niri_*.deb "$O"/dms-shell_*.deb "$O"/maotouying-config_*.deb "$O"/maotouying-extras_*.deb "$R/tmp/"
chroot "$R" bash -c "
dpkg -i /tmp/niri_*.deb 2>&1 || true
dpkg -i /tmp/dms-shell_*.deb 2>&1 || true
apt-get install -f -y
dpkg -i /tmp/maotouying-config_*.deb /tmp/maotouying-extras_*.deb 2>&1 || true
rm /tmp/*.deb
"

echo "==> initramfs..."
chroot "$R" update-initramfs -u -k all 2>&1 || true

echo "==> 制作 squashfs + ISO..."
umount -l "$R/dev/pts" "$R/dev" "$R/proc" "$R/sys" 2>/dev/null || true
rm -rf "$R/tmp/"* "$R/run/"* 2>/dev/null || true

ISODIR="/tmp/maotouying-iso"
rm -rf "$ISODIR"
mkdir -p "$ISODIR/live" "$ISODIR/boot/grub"

KERNEL=$(ls "$R/boot/vmlinuz-"* 2>/dev/null | head -1)
INITRD=$(ls "$R/boot/initrd.img-"* 2>/dev/null | head -1)
[ -n "$KERNEL" ] && cp "$KERNEL" "$ISODIR/live/vmlinuz"
[ -n "$INITRD" ] && cp "$INITRD" "$ISODIR/live/initrd.img"

mksquashfs "$R" "$ISODIR/live/filesystem.squashfs" -comp zstd -Xcompression-level 3 -noappend

# CJK 字体
if [ -f "$O/cjk-font.pf2" ]; then
    cp "$O/cjk-font.pf2" "$ISODIR/boot/grub/fonts/unicode.pf2"
fi

cat > "$ISODIR/boot/grub/grub.cfg" << 'GRUB'
loadfont /boot/grub/fonts/unicode.pf2
set gfxmode=auto
terminal_output gfxterm
set timeout=5
set default=0
menuentry "猫头鹰 OS Live" { linux /live/vmlinuz boot=live quiet splash; initrd /live/initrd.img; }
menuentry "猫头鹰 OS Live (safe)" { linux /live/vmlinuz boot=live nomodeset; initrd /live/initrd.img; }
GRUB

grub-mkrescue -o "$O/maotouying-os-0.1.0-amd64.iso" "$ISODIR" \
    --product-name="猫头鹰 OS" --product-version="0.1.0" 2>&1 | tail -3

ls -lh "$O/maotouying-os-0.1.0-amd64.iso"
echo "猫头鹰 OS 构建完成!"
