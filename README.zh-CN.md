# Multica iOS App

这是一个实验性的 SwiftUI iOS 客户端，用来探索 Multica Web 端核心工作流在 iPhone 上的体验对齐。

> 当前状态：公开源码评审 / 上游贡献提案。仓库目前还没有明确 license，也不是 Multica 官方 App。在与上游 maintainers 确认 license、命名和品牌边界之前，不应分发 build，也不应暗示这是 Multica 官方 App。

## 项目是什么

Multica iOS App 是一个原生 iOS 客户端，连接 Multica API，把核心 workspace 工作流带到手机上：

- Inbox 和 Chat 入口。
- Issues 和 My Issues 工作流。
- Issue 创建、详情、评论、附件、Markdown 渲染、状态流转和重新分配。
- Issues 列表和看板视图，支持排序、状态分组和筛选。
- Projects 列表/详情，支持资源和关联 Issues。
- Settings 下的 workspace 管理。
- Agents、Runtimes、Skills、Autopilots、Labels、Tokens、Members、Notifications 等管理入口。
- 英文和简体中文语言切换。

项目主体是 SwiftUI，并用 Swift Package + Xcode host app 组织。

## 演示视频

交互演示视频通过 HyperFrames 生成，素材来自真实 simulator 操作录屏：

- 英文版：`artifacts/videos/multica-ios-interactive-demo-en.mp4`
- 中文版：`artifacts/videos/multica-ios-interactive-demo-zh.mp4`

如果要给上游 review，建议通过 GitHub Releases、公开对象存储或其他稳定视频链接发布这些 walkthrough。

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
- 用于手动验收的 Multica 账号和 API 访问权限。

## 构建

```bash
swift test --scratch-path /tmp/multicaapp-swift-test

xcodebuild build \
  -project Multi-Casual.xcodeproj \
  -scheme Multi-CasualHost \
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
- Multica desktop/web API response 的 model decoding。
- Issue list/detail/create/edit view models。
- Project、Inbox、Chat、Agent、Runtime、Skill、Autopilot、Label、Token、Notification、Workspace settings 等 view models。
- Markdown block/inline 渲染，包括 pipe table。
- 本地化行为和中文资源覆盖。

最近一次本地验证：

```text
swift test --scratch-path /tmp/multicaapp-swift-test-20260508
316 tests, 0 failures
```

## 上游贡献策略

建议先联系 Multica maintainers，不要直接一次性开巨大 PR：

1. 先问清楚他们更希望这个项目 upstream、成为官方 companion app 候选，还是作为独立 community client。
2. 确认 license、命名、品牌、API 兼容和 roadmap 边界。
3. 如果上游愿意接收，建议拆成多个可 review 的 PR：
   - 项目骨架、auth、workspace、networking。
   - Issues 列表、详情、评论、创建和编辑。
   - Inbox、Projects、Settings 和 Agent 管理。
   - 本地化、性能、UI polish 和 QA。

参考：

- `docs/reports/ios_contribution_and_install_manual_zh_2026-05-08.md`
- `docs/contact/multica_upstream_contact_draft_2026-05-08.md`

## License

当前还没有选择 license。在添加 license 前，默认保留所有权利。
