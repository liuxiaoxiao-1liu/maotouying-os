# 猫头鹰 OS (Maotouying OS)

一个基于 **Ubuntu 24.04 LTS**、使用 **niri 可滚动平铺桌面**、以 **DEB 包管理**的 Linux 发行版。

## 截图

> 启动后运行 `niri-session` 进入桌面。

## 特性

- **niri 26.04** — 可滚动平铺 Wayland 合成器
- **dms (DankMaterialShell)** — 基于 Quickshell + Qt6 QML 的桌面面板
- **全套个人配置** — niri / dms / fuzzel / fcitx5 / GTK 主题即装即用
- **DEB 包管理** — 兼容全部 Ubuntu 软件源，`apt install` 安装任何软件
- **中文支持** — fcitx5 + Noto CJK + GRUB 中文字体
- **Firefox** — Mozilla PPA 原生 .deb，非 Snap

## 快速开始

下载 [最新 ISO](https://github.com/liuxiaoxiao-1liu/maotouying-os/releases/latest)，写入 U 盘：

```bash
sudo dd if=maotouying-os-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress
```

或用 QEMU 测试：

```bash
qemu-system-x86_64 -m 4G -enable-kvm -cdrom maotouying-os-0.1.0-amd64.iso -boot d
```

默认用户 `maotouying`，密码 `maotouying`。

## 桌面组件

| 类别 | 组件 | 来源 |
|------|------|------|
| 合成器 | niri 26.04 | 源码编译 |
| 面板 | dms + quickshell + dgop | 二进制提取 |
| 搜索 | dsearch | 二进制提取 |
| 启动器 | fuzzel | Ubuntu 源 |
| 终端 | kitty | Ubuntu 源 |
| 文件管理 | thunar | Ubuntu 源 |
| 输入法 | fcitx5 + 中文 | Ubuntu 源 |
| 音频 | pipewire + wireplumber | Ubuntu 源 |
| 网络 | NetworkManager + iwd | Ubuntu 源 |
| 浏览器 | Firefox (Mozilla PPA) | PPA |
| 主题 | Breeze + Noto CJK | Ubuntu 源 |
| 工具 | matugen / shorindms / wl-clipboard | 二进制 + Ubuntu 源 |

## 从源码构建

需要 Docker：

```bash
git clone https://github.com/liuxiaoxiao-1liu/maotouying-os.git
cd maotouying-os

# 1. 捕获当前系统配置
make configs

# 2. 构建 Docker 镜像
make docker-build

# 3. 进入构建容器
make shell

# 4. 容器内运行完整构建
bash scripts/build-iso.sh
```

构建全程使用清华镜像源，国内网络友好。

## 项目结构

```
├── Makefile              # 构建命令
├── docker/               # Docker 构建容器
├── configs/              # 桌面配置文件
│   ├── niri/             # niri + dms 配置
│   ├── fuzzel/           # 启动器配置
│   ├── fcitx5/           # 输入法配置
│   └── gtk/              # GTK 主题配置
├── scripts/              # 自定义工具脚本
│   ├── niri-binds        # 快捷键查看器
│   ├── niri-pick         # 窗口信息/取色器
│   ├── niri-force-kill-window  # 窗口强杀
│   └── screenshot-sound.sh     # 截图音效
├── packages/             # DEB 包定义
│   ├── niri/             # niri 合成器
│   ├── dms/              # 桌面面板
│   ├── maotouying-desktop/ # 桌面元包
│   └── maotouying-config/  # 配置文件包
└── output/               # 构建产物
    ├── *.deb             # DEB 包
    └── *.iso             # 可启动 ISO
```

## 许可

MIT
