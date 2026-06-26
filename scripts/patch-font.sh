#!/bin/bash
# 给 ISO 加中文 GRUB 字体，0 流量
set -e

ISO="/build/output/maotouying-os-0.1.0-amd64.iso"
OUTDIR="/build/output"
WORK="/tmp/font-patch"

echo "==> [1/4] 使用预生成的 CJK 字体..."
ls -lh "$OUTDIR/cjk-font.pf2"

echo "==> [2/4] 提取并修改 ISO..."
mkdir -p "$WORK/orig" "$WORK/new/boot/grub/fonts"
cd "$WORK/orig"
xorriso -osirrox on -indev "$ISO" -extract / ./ 2>&1 | tail -1

# 拷贝启动文件 + 新字体
cp -r boot efi efi.img boot.catalog .disk System mach_kernel ../new/ 2>/dev/null || true
cp -r live ../new/ 2>/dev/null || true
cp "$OUTDIR/cjk-font.pf2" "$WORK/new/boot/grub/fonts/unicode.pf2"

# 更新 grub.cfg 加载字体
cat > "$WORK/new/boot/grub/grub.cfg" << 'GRUB'
loadfont /boot/grub/fonts/unicode.pf2
set gfxmode=auto
terminal_output gfxterm
set timeout=5
set default=0
menuentry "猫头鹰 OS Live" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}
menuentry "猫头鹰 OS Live (安全模式)" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd.img
}
GRUB

echo "==> [3/4] 重新打包 ISO..."
grub-mkrescue -o "$OUTDIR/maotouying-os-0.1.0-amd64.iso" "$WORK/new" \
    --product-name="猫头鹰 OS" 2>&1 | tail -3

echo "==> [4/4] 完成!"
ls -lh "$OUTDIR/maotouying-os-0.1.0-amd64.iso"
