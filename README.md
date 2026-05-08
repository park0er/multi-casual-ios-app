# Multica iOS App

A production-used SwiftUI iOS client for Multica, built to bring the Multica web app's core workspace and agent-management workflows to iPhone.

> Status: public source review / upstream contribution proposal. This repository is not an official Multica app. The code is public for review only under the repository's source-review license; do not copy, redistribute, publish builds, or imply official Multica endorsement unless separate written permission is granted.

## What It Is

Multica iOS App is a native iOS client that connects to Multica APIs and brings the web product's workspace workflows to iPhone. It is not a throwaway prototype: it has been used in our internal company workflow and is designed as a full mobile counterpart to the web app.

- Inbox and Chat entry points.
- Issues and My Issues workflows.
- Issue creation, detail review, comments, attachments, Markdown rendering, status changes, and reassignment.
- List and board-style issue views with sorting and status grouping.
- Project list/detail workflows with resources and related Issues.
- Settings surfaces for workspace administration.
- Agent, Runtime, Skill, Autopilot, Label, token, member, and notification management.
- English and Simplified Chinese language switching.

The app is written in SwiftUI and organized as a Swift Package plus an Xcode host app.

## Product Maturity

This project aims for practical web parity rather than a narrow demo. The current implementation covers the everyday loop we use internally: monitor Inbox and Chat, triage Issues, inspect issue details and comments, create/edit/reassign work, review Projects, and manage Agents/Runtimes/Skills/Autopilots from Settings.

The repository remains a contribution proposal, not an official Multica release. The point of opening it is to let Multica maintainers review a substantially complete iOS implementation and decide the right path: upstream, official companion app, or a separately maintained client.

## Demo Videos

Interactive simulator walkthroughs are generated with HyperFrames from real app interaction recordings:

- English: https://github.com/park0er/Multi-Casual/releases/download/demo-2026-05-08/multica-ios-interactive-demo-en.mp4
- Chinese: https://github.com/park0er/Multi-Casual/releases/download/demo-2026-05-08/multica-ios-interactive-demo-zh.mp4

The files are published through the `demo-2026-05-08` GitHub Release.

## Repository Layout

```text
Multi-Casual/
  Core/                 Shared auth, network, cache, localization, design helpers
  Features/             SwiftUI feature areas
  Models/               API models and decoding support
Multi-CasualHost/         iOS app host target
Multi-CasualTests/        SwiftPM/XCTest coverage
Multi-CasualUITests/      Simulator UI coverage and demo walkthrough helpers
docs/                   Reports, walkthroughs, contact drafts, and release notes
artifacts/              Generated demo/video artifacts
```

## Requirements

- Xcode 17 or newer.
- iOS Simulator runtime compatible with the project settings.
- Swift 5.9 package tools or newer.
- A Multica account and API access for authenticated/manual testing.

## Build

```bash
swift test --scratch-path /tmp/multicaapp-swift-test

xcodebuild build \
  -project Multi-Casual.xcodeproj \
  -scheme Multi-CasualHost \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If simulator names differ locally, prefer passing a simulator UUID from:

```bash
xcrun simctl list devices available
```

## Test Coverage

The current suite covers:

- API request shapes and workspace scoping.
- Model decoding for Multica desktop/web API responses.
- Issue list/detail/create/edit view models.
- Project, Inbox, Chat, Agent, Runtime, Skill, Autopilot, Label, token, notification, and workspace settings view models.
- Markdown block and inline rendering, including pipe tables.
- Localization behavior and Chinese resource coverage.

Recent local verification:

```text
swift test --scratch-path /tmp/multicaapp-swift-test-20260508
316 tests, 0 failures
```

## Upstream Contribution Strategy

The recommended upstream path is to contact Multica maintainers before opening a large PR:

1. Ask whether this should be upstreamed, become an official companion app candidate, or remain an independent community client.
2. Confirm license, naming, branding, and API compatibility expectations.
3. If upstreaming is welcome, split work into reviewable PRs:
   - Scaffold/auth/workspace/networking.
   - Issues list/detail/comment/create/edit flows.
   - Inbox, Projects, Settings, and Agent management.
   - Localization, performance, UI polish, and QA.

See:

- `docs/reports/ios_contribution_and_install_manual_2026-05-08.md`
- `docs/contact/multica_upstream_contact_draft_2026-05-08.md`

## License

This repository uses a conservative source-review license. It is **not** an open-source license.

You may view the code for evaluation and upstream contribution discussion, but no permission is granted to copy, modify, distribute, commercialize, or reuse the project without written permission. See `LICENSE`.
