#!/bin/bash
# 热修补 ISO：只装 niri .deb，不重新下载任何东西，0 流量
set -e

ISO="/build/output/maotouying-os-0.1.0-amd64.iso"
OUTDIR="/build/output"
WORK="/tmp/patch"
ROOTFS="$WORK/rootfs"
ISODIR="$WORK/iso-new"
DEB_DIR="/build/output"

echo "==> [1/5] 从 ISO 提取 squashfs..."
mkdir -p "$WORK" "$ROOTFS" "$ISODIR"
cd "$WORK"
xorriso -osirrox on -indev "$ISO" -extract / ./ 2>&1 | tail -1

echo "==> [2/5] 解压 squashfs..."
unsquashfs -d "$ROOTFS" ./live/filesystem.squashfs 2>&1 | tail -1

echo "==> [3/5] chroot 安装 niri..."
cp "$DEB_DIR"/niri_*.deb "$ROOTFS/tmp/"
mount --bind /dev "$ROOTFS/dev"
mount --bind /proc "$ROOTFS/proc"
mount --bind /sys "$ROOTFS/sys"
rm -f "$ROOTFS/etc/resolv.conf"
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

chroot "$ROOTFS" /bin/bash << 'INNER'
dpkg -i /tmp/niri_*.deb 2>&1 || true
rm /tmp/niri_*.deb
INNER

umount -l "$ROOTFS/dev" "$ROOTFS/proc" "$ROOTFS/sys" 2>/dev/null || true

# 验证
echo "==> 验证 niri..."
if [ -f "$ROOTFS/usr/bin/niri" ]; then
    echo "✅ niri 安装成功!"
else
    echo "❌ niri 未安装"
    exit 1
fi

echo "==> [4/5] 重新 squashfs..."
mkdir -p "$ISODIR/live" "$ISODIR/boot/grub"
rm -f ./live/filesystem.squashfs
mksquashfs "$ROOTFS" "$ISODIR/live/filesystem.squashfs" \
    -comp zstd -Xcompression-level 3 -noappend

# 从原 ISO 拷贝启动文件
cp ./live/vmlinuz "$ISODIR/live/" 2>/dev/null
cp ./live/initrd.img "$ISODIR/live/" 2>/dev/null
cp -r ./boot/ "$ISODIR/" 2>/dev/null
cp -r ./efi/ "$ISODIR/" 2>/dev/null
cp ./boot.catalog "$ISODIR/" 2>/dev/null
cp ./efi.img "$ISODIR/" 2>/dev/null

echo "==> [5/5] 打包新 ISO..."
rm -f "$OUTDIR/maotouying-os-0.1.0-amd64.iso"
grub-mkrescue -o "$OUTDIR/maotouying-os-0.1.0-amd64.iso" "$ISODIR" \
    --product-name="猫头鹰 OS" 2>&1 | tail -3

ls -lh "$OUTDIR/maotouying-os-0.1.0-amd64.iso"
echo "猫头鹰 OS(修补版) 完成!"
