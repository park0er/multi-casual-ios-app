# Multica iOS App

An experimental SwiftUI iOS client for Multica, built to explore mobile parity with the Multica web app.

> Status: public source review / upstream contribution proposal. This repository currently has no declared license and is not an official Multica app. Do not redistribute builds or imply official Multica endorsement until license, naming, and branding boundaries are confirmed with the upstream maintainers.

## What It Is

Multica iOS App is a native iOS client that connects to Multica APIs and brings core workspace workflows to iPhone:

- Inbox and Chat entry points.
- Issues and My Issues workflows.
- Issue creation, detail review, comments, attachments, Markdown rendering, status changes, and reassignment.
- List and board-style issue views with sorting and status grouping.
- Project list/detail workflows with resources and related Issues.
- Settings surfaces for workspace administration.
- Agent, Runtime, Skill, Autopilot, Label, token, member, and notification management.
- English and Simplified Chinese language switching.

The app is written in SwiftUI and organized as a Swift Package plus an Xcode host app.

## Demo Videos

Interactive simulator walkthroughs are generated with HyperFrames from real app interaction recordings:

- English: `artifacts/videos/multica-ios-interactive-demo-en.mp4`
- Chinese: `artifacts/videos/multica-ios-interactive-demo-zh.mp4`

For upstream review, publish these walkthroughs through GitHub Releases, a public object store, or another stable video host.

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

No license has been selected yet. All rights are reserved until a license is added.
