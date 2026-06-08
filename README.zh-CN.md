# Multi Casual iOS App

这是一个已经在内部业务中使用的 SwiftUI iOS 客户端，用来对接 multi-casual 官方云服务，并把 multi-casual Web 端核心 workspace 和 Agent 管理工作流带到 iPhone 上。

> 当前状态：公开源码评审 / 上游贡献提案。这个仓库是对接 multi-casual 官方云服务的独立 iOS 客户端，不是 multi-casual 官方 App。代码仅按仓库的 source-review license 公开用于评审；未经书面许可，不得复制、改造、再发布、分发 build，也不得暗示这是 multi-casual 官方 App。

## 项目是什么

Multi Casual iOS App 是一个原生 iOS 客户端，连接 multi-casual 官方云 API，把 multi-casual Web 产品里的 workspace 工作流带到手机上。它不是一个半吊子的 demo：这个 App 已经进入我们的企业内部业务流程，并且目标是成为 Web 端的完整移动端对标实现。

这里改名只针对这个 iOS 客户端项目和 GitHub 仓库名；服务对接仍然是 multi-casual。部分源码路径、scheme、bundle ID 和 API 域名仍保留 multi-casual 标识，这样当前 App 代码和构建 target 可以暂时不动。

multi-casual 官方链接：

- Multica 云服务：https://multica.ai/
- Multica 官方开源项目：https://github.com/multica-ai/multica

- Inbox 和 Chat 入口。
- Issues 和 My Issues 工作流。
- Issue 创建、详情、评论、附件、Markdown 渲染、状态流转和重新分配。
- Issues 列表和看板视图，支持排序、状态分组和筛选。
- Projects 列表/详情，支持资源和关联 Issues。
- Settings 下的 workspace 管理。
- Agents、Runtimes、Skills、Autopilots、Labels、Tokens、Members、Notifications 等管理入口。
- 英文和简体中文语言切换。

项目主体是 SwiftUI，并用 Swift Package + Xcode host app 组织。

## 产品成熟度

这个项目追求的是实际可用的 Web parity，而不是狭窄的演示项目。当前实现覆盖了我们内部日常使用的闭环：查看 Inbox 和 Chat、处理 Issues、进入 Issue 详情和 comments、创建/编辑/重新分配工作、查看 Projects，并在 Settings 里管理 Agents、Runtimes、Skills、Autopilots 等能力。

仓库目前仍然是贡献提案，不是 multi-casual 官方发布版本。公开它的目的，是让 multi-casual maintainers 能审阅一个已经相当完整的 iOS 实现，然后决定它应该 upstream、成为官方 companion app，还是作为单独维护的客户端继续推进。

## 演示视频

交互演示视频通过 HyperFrames 生成，素材来自真实 simulator 操作录屏：

- 英文版：https://github.com/park0er/multi-casual-ios-app/releases/download/demo-2026-05-08/multi-casual-ios-interactive-demo-en.mp4
- 中文版：https://github.com/park0er/multi-casual-ios-app/releases/download/demo-2026-05-08/multi-casual-ios-interactive-demo-zh.mp4

这些 walkthrough 已通过 `demo-2026-05-08` GitHub Release 发布。

## 目录结构

```text
Multi-Casual/
  Core/                 Auth、网络、缓存、本地化、设计系统工具
  Features/             SwiftUI 功能模块
  Models/               API models 和 decoding 支持
Multi-CasualHost/         iOS app host target
Multi-CasualTests/        SwiftPM/XCTest 测试
Multi-CasualUITests/      Simulator UI 测试和 demo walkthrough
docs/                   报告、walkthrough、联系上游草稿和发布清单
artifacts/              生成的 demo/video artifacts
```

## 环境要求

- Xcode 17 或更新版本。
- 与项目配置匹配的 iOS Simulator runtime。
- Swift 5.9 package tools 或更新版本。
- 用于手动验收的 multi-casual 账号和 API 访问权限。

## 构建

这个仓库用同一套 Swift 代码构建两个 iOS 包：

| 包 | Scheme | Bundle ID | API |
| --- | --- | --- | --- |
| multi-casual 官方云服务 | `Multi-CasualHost` | `ai.multi-casual.app` | `https://api.multi-casual.ai` |
| 小米自部署版 | `Multi-Casual-Xiaomi` | `ai.multi-casual.app.xiaomi` | `http://staging-multi-casual.ad.xiaomi.srv` |

这两个包必须保持独立，因为它们对应不同服务身份、登录 token、WebSocket 地址、URL Scheme、Keychain service、APNs topic 和分发渠道。

```bash
swift test --scratch-path /tmp/multi-casualapp-swift-test

xcodebuild build \
  -project Multi-Casual.xcodeproj \
  -scheme Multi-CasualHost \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

构建小米自部署版：

```bash
xcodebuild build \
  -project Multi-Casual.xcodeproj \
  -scheme Multi-Casual-Xiaomi \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

如果本机 simulator 名称不同，建议先查 UUID：

```bash
xcrun simctl list devices available
```

## 测试覆盖

当前测试覆盖：

- API request shape 和 workspace scope。
- multi-casual desktop/web API response 的 model decoding。
- Issue list/detail/create/edit view models。
- Project、Inbox、Chat、Agent、Runtime、Skill、Autopilot、Label、Token、Notification、Workspace settings 等 view models。
- Markdown block/inline 渲染，包括 pipe table。
- 本地化行为和中文资源覆盖。

最近一次本地验证：

```text
swift test --scratch-path /tmp/multi-casualapp-swift-test-20260508
316 tests, 0 failures
```

## License

本仓库使用保守的 source-review license。它**不是**开源 license。

你可以为评估和上游贡献讨论而查看代码，但未经书面许可，不得复制、修改、分发、商业化或复用本项目。详见 `LICENSE`。
