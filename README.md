# 猫头鹰 OS

niri 可滚动平铺桌面 + Ubuntu 24.04 + DEB 包管理。

## 安装

下载 [ISO](https://github.com/liuxiaoxiao-1liu/maotouying-os/releases/latest)，写入 U 盘：

```bash
sudo dd if=maotouying-os-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress
```

或 QEMU 测试：

```bash
qemu-system-x86_64 -m 4G -enable-kvm -cdrom maotouying-os-0.1.0-amd64.iso -boot d
```

默认用户 `maotouying`，密码 `maotouying`。登录后运行 `niri-session` 启动桌面。

## 桌面

| 组件 | |
|------|------|
| 合成器 | niri 26.04 |
| 面板 | dms (quickshell + dgop) |
| 启动器 | fuzzel |
| 终端 | kitty |
| 输入法 | fcitx5 |
| 文件管理 | thunar |
| 浏览器 | Firefox |

Mod + D 启动应用，Mod + H/L 滚动工作区。

## 构建

```bash
git clone https://github.com/liuxiaoxiao-1liu/maotouying-os.git
cd maotouying-os
make docker-build
docker run --rm --privileged --network=host \
  -v $(pwd)/output:/build/output \
  -v $(pwd)/scripts:/build/scripts:ro \
  maotouying-build bash /build/scripts/build-iso.sh
```

## 许可

MIT
