# VPS Network Test Script

基于 [spiritLHLS/ecs](https://github.com/spiritLHLS/ecs) 净化修改的 **VPS 网络测试专用脚本**。

## 与原版的区别

| 项目 | 原版 (spiritLHLS/ecs) | 本仓库 |
|---|---|---|
| **测试范围** | 系统信息 + CPU/内存/磁盘压测 + 流媒体解锁 + 网络 | **仅网络测试** |
| **系统配置修改** | 修改 sysctl / limits.conf | ❌ 已移除 |
| **结果回传** | 自动上传结果到作者服务器生成短链 | ❌ 已移除 |
| **运行计数** | 上报运行次数到作者服务器 | ❌ 已移除 |
| **自动更新** | 自动从 GitHub 拉取新版本覆盖自身 | ❌ 已移除 |
| **流媒体解锁** | Netflix/TikTok/OpenAI 等解锁检测 | ❌ 已移除 |
| **硬件压测** | Geekbench / sysbench / fio 磁盘压测 | ❌ 已移除 |

## 功能

- **三网回程路由测试**（电信/联通/移动）
- **三网路由追踪**（nexttrace）
- **全国三网延迟测试**（ecs_ping）
- **节点测速**（speedtest）
- **四地回程路由**（广州/上海/北京/成都）

## 使用方法

### 一键执行

```bash
curl -fsSL https://raw.githubusercontent.com/harice-huang/vps-test/main/ecs.sh | sudo bash
```

### 下载后执行

```bash
wget https://raw.githubusercontent.com/harice-huang/vps-test/main/ecs.sh
chmod +x ecs.sh
sudo ./ecs.sh
```

### 参数说明

| 参数 | 说明 |
|---|---|
| `-base` | 仅测试基础网络（不下载二进制，最快） |
| `-bansp` | 不测速 |
| `-en` | 英文输出 |
| `-m N` | 直接执行菜单第 N 项（非交互模式） |

## 依赖

- `curl` / `wget` / `ping` / `tar` / `unzip`（脚本自动安装）
- root 权限
- 出站网络（访问 GitHub Releases 下载测试二进制）

## 下载的二进制

| 工具 | 来源 | 用途 |
|---|---|---|
| nexttrace | [nxtrace/NTrace-core](https://github.com/nxtrace/NTrace-core) | 路由追踪 |
| backtrace | [oneclickvirt/backtrace](https://github.com/oneclickvirt/backtrace) | 三网回程路由 |

## 许可证

继承原项目 GPL-3.0 许可证
