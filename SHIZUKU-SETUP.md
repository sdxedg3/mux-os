# Shizuku Setup (Mux-OS)

## 核心链路

Termux → `rish` → Shizuku → 高权限 shell

## 安装状态

| 组件 | 位置 | 说明 |
|------|------|------|
| `shizuku` 激活脚本 | `/data/data/com.termux/files/usr/bin/shizuku` | 重启后自动激活 Shizuku |
| `rish` 命令 | `/data/data/com.termux/files/usr/bin/rish` | Shizuku shell 入口 |
| `rish_shizuku.dex` | `$HOME/rish_shizuku.dex` | rish 核心文件 (59672 bytes, MD5: `2a5fb0c2705b3fe87aa567ffe6d471b7`) |

## 重启后的激活流程

```
1. 下拉通知栏 → 点「无线调试」快速开关
2. Termux 执行:  shizuku
```

`shizuku` 脚本自动扫描端口 → ADB 连接 → 启动 Shizuku → 关闭无线调试。

## Mux-OS 命令

| 命令 | 说明 |
|------|------|
| `mux <app>` | 启动应用 |
| `mux <app> <query>` | 在应用或网页中搜索 |
| `mux ps` | 列出运行中的应用进程 |
| `mux top` | CPU/内存概览 |
| `mux screencap` | 截屏 |
| `mux notify <标题> <内容>` | 发送通知 |
| `mux kill <app>` | 强制关闭应用（Shizuku 优先） |

## 直接通过 Shizuku 执行命令

```bash
rish -c 'command'
```

示例:
```bash
rish -c 'am force-stop com.android.chrome'
rish -c 'pm list packages'
rish -c 'id'
```

## 注意

`screencap` 保存后会自动触发媒体扫描，相册可见。如果还是看不到，检查 `/sdcard/Pictures/Screenshots/` 目录是否存在。

## 重启后激活

```
1. 下拉通知栏 → 点「无线调试」开关
2. Termux 执行:  shizuku
```

`shizuku` 脚本自动扫描端口 → ADB 连接 → 启动 Shizuku → 关闭无线调试。

## 参考文件

| 文件 | 说明 |
|------|------|
| `/root/mux-os/mux` | 主命令入口 |
| `/root/mux-os/mux-kill.sh` | 强制关闭应用逻辑 |
| `/data/data/com.termux/files/usr/bin/shizuku` | Shizuku 激活脚本 |
| `/data/data/com.termux/files/usr/bin/rish` | Shizuku shell 入口 |
