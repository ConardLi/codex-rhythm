# Codex Rhythm

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-111111?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-原生-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-2E7D32.svg)](LICENSE)

**一个原生的 macOS 菜单栏工具：查看 Codex 额度，并尽量在你真正需要使用之前，让下一轮 5 小时重置倒计时先走起来。**

[English](README.md)

Codex Rhythm 把额度监控、计时助手、限额重置和未来三轮时间预测放进了一个简洁的毛玻璃控制中心。项目使用 SwiftUI 与 AppKit 编写，没有第三方运行时依赖。

<img src="Resources/AppIcon/AppIcon-source.png" alt="Codex Rhythm 图标" width="128">

> Codex Rhythm 是独立社区项目，与 OpenAI 没有隶属、合作或背书关系。

<p align="center">
  <img src="Documentation/assets/codex-rhythm-control-center.png" alt="Codex Rhythm 控制中心" width="420">
</p>

## 它解决什么问题

Codex 的 5 小时额度恢复后，新一轮倒计时通常要等下一次实际使用才会开始。如果等到真正开始工作时才触发，用完额度后，下一次恢复时间也会跟着推迟。

Codex Rhythm 会观察官方额度状态。当它确认当前没有真实的 5 小时计时窗口时，可以发送一次受保护的 Codex 请求，提前让倒计时运行。简单来说，就是尽量把等待额度恢复的时间，放到你没有使用 Codex 的时候。

## 主要功能

- 在 macOS 菜单栏显示 5 小时额度与一周额度。
- 每 30 秒同步一次当前 Codex 用量。
- 官方请求不可用时，读取最近的本地 Codex 响应头作为备用。
- 能区分真实计时窗口与 0% 使用量时不断移动的占位时间。
- 提供两种计时助手模式：
  - **自动守候**：在指定使用时段内，按 5、10、15 或 30 分钟间隔检查。
  - **固定时间**：每天在一个或两个指定时间检查。
- 提供明确的“手动启动计时”按钮。
- 不会只根据命令成功就宣称启动，而是继续读取官方额度确认结果。
- 点击 **时间预测**，查看未来三次预计重置时间。
- 展示可用的限额重置次数，使用前必须再次确认。
- 原生 SwiftUI/AppKit 实现，无统计、无广告、无第三方 SDK。

## 系统要求

- macOS 13 Ventura 或更高版本。
- Codex 桌面端或 Codex CLI 已使用 ChatGPT 账号登录。
- 从源码构建时，需要安装 Xcode Command Line Tools。

如未安装命令行工具，可执行：

```bash
xcode-select --install
```

## 从源码安装

进入项目根目录后运行：

```bash
./scripts/install.sh
```

安装脚本会：

1. 在本机编译并临时签名 `CodexRhythm.app`；
2. 安装到 `~/Applications`；
3. 注册当前用户的 LaunchAgent；
4. 立即启动菜单栏应用。

全程不需要管理员权限。再次运行同一个脚本即可更新。

卸载：

```bash
./scripts/uninstall.sh
```

卸载后会保留 `~/Library/Logs` 中的诊断日志，方便排查历史问题。

## 计时助手怎么工作

计时助手默认关闭。开启后，只有以下条件全部满足时才会自动发送请求：

1. 当前数据刚刚来自官方额度接口；
2. 没有真实的 5 小时计时窗口；
3. 一周剩余额度高于保护线；
4. 当前时间符合自动守候时段或固定时间设置；
5. 本轮没有处理过，也没有进入冷却或达到重试上限。

启动请求通过本机 Codex CLI 执行，使用 ChatGPT 登录、临时会话和只读沙箱。CLI 返回成功后，程序还会继续轮询官方额度：只有观察到使用量变化，或连续三次获得稳定的重置时间，才会提示“计时已确认启动”。

需要注意：即使要求模型只返回几个字，Codex 请求仍可能包含系统上下文，因此不能保证输入 Token 极少。额度计算方式和窗口规则由服务端控制，也可能发生变化。

## 时间预测

点击“5 小时额度”右侧的 **时间预测**，可以看到未来三次预计重置时间：

- 第一次使用官方确认的当前重置时间；
- 后两次按每轮 5 小时继续推算。

预测成立的前提是每轮恢复后，计时助手都及时启动下一轮。电脑休眠、断网、程序退出或触发延迟，都会让实际时间向后顺延。

## 数据与隐私

Codex Rhythm 会读取 `~/.codex/auth.json` 中已有的 Codex 登录信息，并仅用它向 `chatgpt.com` 请求额度数据。凭据只在内存中使用，不会写入项目日志。项目没有遥测服务，也没有自己的服务器。

计时助手只有在你开启它或主动点击按钮时，才会运行本机 `codex` 可执行文件。完整信任边界请阅读 [SECURITY.md](SECURITY.md)。

## 构建与测试

```bash
./scripts/test.sh
./scripts/build.sh
```

构建产物位于：

```text
build/CodexRhythm.app
```

## 工程结构

```text
Sources/CodexRhythm/       分层组织的应用源码
├── App/                   应用入口与生命周期协调
├── Domain/                额度模型与纯解析逻辑
├── Features/              控制中心与计时助手
├── Services/              Codex API 与 CLI 集成
└── Support/               日志等共享能力
Resources/                 应用图标等运行时资源
SupportingFiles/           Info.plist 与 Bundle 元数据
Tests/CodexRhythmTests/    确定性的回归测试
scripts/                   构建、安装、测试、卸载和发布脚本
Documentation/             架构、发布流程和介绍文章
.github/                   CI 与协作模板
```

依赖边界和各模块职责见[架构文档](Documentation/ARCHITECTURE.md)。

## 参与贡献

欢迎提交 Issue 和范围清晰的 Pull Request。分享日志或截图前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，任何 Codex 凭据和账号标识都不能出现在公开内容中。

## 兼容性说明

Codex Rhythm 使用当前 Codex 客户端正在使用的相关接口，但这些接口并不是对第三方工具作出的稳定兼容承诺。数据无法确认时，程序会明确显示不可用，而不是把旧数据伪装成实时状态。

## 许可证与来源

项目采用 [MIT License](LICENSE)。第三方版权和项目演进关系记录在 [NOTICE](NOTICE) 中。
