# 猫头鹰 OS (Maotouying OS)

基于 **Ubuntu 24.04 LTS** + **niri 可滚动平铺桌面** + **DEB 包管理**的 Linux 发行版。

---

## 硬件要求

| 项目 | 最低 | 推荐 |
|------|------|------|
| CPU | x86_64 双核 | 四核及以上 |
| 内存 | 2 GB | 4 GB+ |
| 磁盘 | 10 GB | 20 GB+ |
| 显卡 | 支持 Wayland | Intel/AMD 集显，NVIDIA 需闭源驱动 |
| 启动方式 | UEFI | UEFI |

> 仅支持 UEFI 启动，不支持传统 BIOS / Legacy 模式。

---

## 安装指南

### 方式一：写入 U 盘（Live 启动）

**1. 下载 ISO**

从 [Releases](https://github.com/liuxiaoxiao-1liu/maotouying-os/releases/latest) 下载 `maotouying-os-0.1.0-amd64.iso`。

**2. 写入 U 盘**

Linux / macOS：

```bash
sudo dd if=maotouying-os-0.1.0-amd64.iso of=/dev/sdX bs=4M status=progress
```

> ⚠️ 把 `/dev/sdX` 换成你的 U 盘设备名（用 `lsblk` 查看），**不要搞错**，会覆盖整个磁盘。

Windows：用 [Rufus](https://rufus.ie) 或 [balenaEtcher](https://www.balena.io/etcher/) 写入。

**3. 启动**

- 插入 U 盘，重启电脑
- 按 `F2` / `F12` / `Del` 进入 BIOS/UEFI 启动菜单
- 选择从 U 盘启动
- GRUB 菜单出现后，选择「猫头鹰 OS Live」回车

**4. 登录**

```
用户名: maotouying
密码:   maotouying
```

**5. 启动桌面**

登录后运行：

```bash
niri-session
```

这会启动 niri 合成器 + dms 面板 + fcitx5 输入法。你也可以在登录时自动启动，见下方「设置为默认会话」。

### 方式二：虚拟机测试

```bash
qemu-system-x86_64 -m 4G -enable-kvm \
  -cdrom maotouying-os-0.1.0-amd64.iso -boot d
```

或导入 VirtualBox / virt-manager。

### 方式三：安装到硬盘

目前 Live 模式运行。后续版本会加入 Calamares 安装器支持永久安装。临时方案：

```bash
# 在 Live 系统中手动分区并解压 rootfs
sudo su
fdisk /dev/sdX          # 分区
mkfs.ext4 /dev/sdX1     # 格式化
mount /dev/sdX1 /mnt
unsquashfs -d /mnt /run/live/medium/live/filesystem.squashfs
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt grub-install /dev/sdX
chroot /mnt update-grub
```

---

## 桌面操作

### 键盘快捷键

猫头鹰 OS 的桌面操作完全围绕 niri 的滚动平铺模型设计。按 `Mod` 键查看快捷键面板（`niri-binds` 脚本）。

| 快捷键 | 操作 |
|--------|------|
| `Mod + H` | 向左滚动 |
| `Mod + L` | 向右滚动 |
| `Mod + J` | 聚焦下一窗口 |
| `Mod + K` | 聚焦上一窗口 |
| `Mod + Return` | 打开终端（kitty） |
| `Mod + D` | 打开启动器（fuzzel） |
| `Mod + Q` | 关闭当前窗口 |
| `Mod + Shift + E` | 退出 niri |
| `Mod + Shift + S` | 截图 |
| `Mod + P` | 取色器 / 窗口信息复制 |
| `Mod + 鼠标点击` | 强制结束无响应窗口 |

> Mod = Super 键（通常是键盘上的 Windows 徽标键）

### 桌面面板（dms）

左侧是 dms 桌面面板，提供：
- 工作区概览
- 应用启动器
- 系统托盘（网络 / 音量 / 电源）
- 通知中心

### 输入法

按 `Ctrl + Space` 切换中英文。默认使用拼音。

### 截图

按 `Mod + Shift + S` 截图，保存到 `~/Pictures/Screenshots/Niri-screenshots/`。伴随快门音效。

---

## 包管理

猫头鹰 OS 使用 **apt / dpkg**，兼容所有 Ubuntu 源。

```bash
sudo apt update                  # 刷新软件列表
sudo apt install <包名>           # 安装软件
sudo apt remove <包名>            # 卸载软件
sudo apt upgrade                 # 升级全部软件
```

预装的自定义 DEB 包：

| 包名 | 内容 |
|------|------|
| `niri` | niri Wayland 合成器 |
| `dms-shell` | 桌面面板 + quickshell + dgop + dsearch |
| `maotouying-config` | 全套桌面配置（安装到 `/etc/skel/`） |
| `maotouying-extras` | matugen + shorindms + xwayland-satellite |

---

## 设置为默认会话（自动启动 niri）

在 `~/.bash_profile` 或 `~/.zprofile` 中追加：

```bash
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec niri-session
fi
```

这样登录 tty1 后自动进入桌面，无需手动输入 `niri-session`。

---

## 构建

从源码构建猫头鹰 OS：

```bash
git clone https://github.com/liuxiaoxiao-1liu/maotouying-os.git
cd maotouying-os

# 1. 构建 Docker 镜像（需要 Docker）
make docker-build

# 2. 捕获当前 Arch 系统的桌面配置
make configs

# 3. 完整构建 ISO
docker run --rm --privileged --network=host \
  -v $(pwd)/output:/build/output \
  -v $(pwd)/scripts:/build/scripts:ro \
  maotouying-build bash /build/scripts/build-iso.sh
```

构建全程使用清华镜像源，国内网络友好。构建一次约消耗 2GB 流量。

---

## 自带工具

| 工具 | 命令 | 用途 |
|------|------|------|
| 快捷键面板 | `niri-binds` | 在 kitty + fzf 中显示所有快捷键 |
| 窗口取色 | `niri-pick` | 复制窗口信息或屏幕颜色 |
| 窗口强杀 | `niri-force-kill-window` | 鼠标点击杀死无响应窗口 |

---

## 项目结构

```
maotouying-os/
├── docker/               # Docker 构建容器（Ubuntu 24.04）
├── configs/              # 桌面配置文件
│   ├── niri/             # niri + dms 全套配置
│   ├── fuzzel/           # 启动器主题和快捷键
│   ├── fcitx5/           # 中文输入法配置
│   └── gtk/              # Breeze 主题设置
├── scripts/              # 自定义工具和构建脚本
├── packages/             # DEB 打包模板
└── output/               # 构建产物（ISO + DEB）
```

## 技术栈

| 层 | 技术 |
|----|------|
| 底座 | Ubuntu 24.04 LTS (Noble Numbat) |
| 内核 | linux-image-generic (6.8) |
| 初始化 | systemd |
| 显示协议 | Wayland |
| 合成器 | niri 26.04 (Rust) |
| 桌面面板 | dms (Quickshell / Qt6 QML) |
| 包管理 | apt + dpkg |

## 许可

MIT License
