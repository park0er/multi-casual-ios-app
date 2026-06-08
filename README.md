# Multi Casual iOS App

[中文版](README.zh-CN.md)

A production-used SwiftUI iOS client for multi-casual's official cloud service, built to bring the multi-casual web app's core workspace and agent-management workflows to iPhone.

> Status: public source review / upstream contribution proposal. This repository is an independent iOS client for multi-casual's official cloud service, not an official multi-casual app. The code is public for review only under the repository's source-review license; do not copy, redistribute, publish builds, or imply official multi-casual endorsement unless separate written permission is granted.

## What It Is

Multi Casual iOS App is a native iOS client that connects to multi-casual's official cloud APIs and brings the multi-casual web product's workspace workflows to iPhone. It is not a throwaway prototype: it has been used in our internal company workflow and is designed as a full mobile counterpart to the web app.

Only this client project's public name and GitHub repository name have moved to Multi Casual. The service integration remains multi-casual, and some source paths, schemes, bundle IDs, and API domains still contain multi-casual identifiers so the current app code and build targets remain unchanged.

Official multi-casual links:

- Multica cloud service: https://multica.ai/
- Multica official open-source project: https://github.com/multica-ai/multica

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

The repository remains a contribution proposal, not an official multi-casual release. The point of opening it is to let multi-casual maintainers review a substantially complete iOS implementation and decide the right path: upstream, official companion app, or a separately maintained client.

## Implementation Scope

The app is broad enough that the repository should be read as a web-parity client, not as a single-screen experiment. Current scale markers from the codebase and verification report:

- 146 public API client methods in `APIClient.swift`.
- 105 unique API path literals, used across 144 call sites.
- 15 API capability domains covered.
- 16 major feature groups and 90+ user-visible feature points.
- 5 primary tabs: Inbox, Issues, My Issues, Projects, and Settings.
- 11 Settings management surfaces: Workspaces, Workspace Details, Members, Notifications, API Tokens, Labels, Agents, Autopilots, Runtimes, Skills, and Feedback.
- 64 production Swift files, 35 test Swift files, and 88 SwiftUI `View` structs.
- 316 passing Swift/XCTest tests in the latest contribution verification run.

The API surface currently spans:

| Domain | Mobile coverage |
| --- | --- |
| Auth | Email-code login, code verification, logout, and session restoration. |
| User & config | Current user, profile update, CLI token issuance, and app configuration. |
| Workspaces | Workspace list/create/read/update/leave/delete plus current workspace scoping. |
| Members | Workspace member listing, creation/invitation, role updates, and removal. |
| Invitations | Personal and workspace invitations, accept/decline, and revoke flows. |
| Inbox | Inbox list, unread count, read/archive actions, mark-all-read, and bulk archive flows. |
| Issues | List/search/detail/create/quick-create/update/delete, batch actions, children, progress, usage, and active tasks. |
| Comments | Issue comments, add/edit/delete, reactions, and agent run message reading. |
| Projects | Project list/search/detail/create/update/delete and project resource management. |
| Agents | Agent list/detail/create/update, avatar upload, archive/restore, cancel tasks, task snapshots, activity, run counts, and skill binding. |
| Runtimes | Runtime list/delete, usage, task activity, agent/hour usage, model refresh, local skill refresh/import, and runtime update flows. |
| Skills | Skill list/detail/create/update/import/delete and Agent skill assignment. |
| Autopilots | Autopilot list/detail/create/update/delete, manual trigger, run history, and trigger management. |
| Chat | Chat sessions, messages, session creation/archive, pending tasks, read state, and task cancellation. |
| Settings tools | Uploads, attachments, labels, pins, subscribers, notification preferences, personal access tokens, feedback, and push-token registration. |

## Repository Layout

```text
Multi-Casual/
  Core/                 Shared auth, network, cache, localization, design helpers
  Features/             SwiftUI feature areas
  Models/               API models and decoding support
Multi-CasualHost/         iOS app host target
Multi-CasualTests/        SwiftPM/XCTest coverage
Multi-CasualUITests/      Simulator UI coverage and demo walkthrough helpers
```

## Requirements

- Xcode 17 or newer.
- iOS Simulator runtime compatible with the project settings.
- Swift 5.9 package tools or newer.
- A multi-casual account and API access for authenticated/manual testing.

## Build

The repository can build two iOS app packages from the same Swift codebase:

| Package | Scheme | Bundle ID | API |
| --- | --- | --- | --- |
| multi-casual official cloud | `Multi-CasualHost` | `ai.multi-casual.app` | `https://api.multi-casual.ai` |
| Xiaomi self-hosted | `Multi-Casual-Xiaomi` | `ai.multi-casual.app.xiaomi` | `http://staging-multi-casual.ad.xiaomi.srv` |

The packages stay separate because they use different server identities, auth tokens, WebSocket endpoints, URL schemes, Keychain services, APNs topics, and release channels.

```bash
swift test --scratch-path /tmp/multi-casualapp-swift-test

xcodebuild build \
  -project Multi-Casual.xcodeproj \
  -scheme Multi-CasualHost \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Build the Xiaomi self-hosted package:

```bash
xcodebuild build \
  -project Multi-Casual.xcodeproj \
  -scheme Multi-Casual-Xiaomi \
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
- Model decoding for multi-casual desktop/web API responses.
- Issue list/detail/create/edit view models.
- Project, Inbox, Chat, Agent, Runtime, Skill, Autopilot, Label, token, notification, and workspace settings view models.
- Markdown block and inline rendering, including pipe tables.
- Localization behavior and Chinese resource coverage.

Recent local verification:

```text
swift test --scratch-path /tmp/multi-casualapp-swift-test-20260508
316 tests, 0 failures
```

## License

This repository uses a conservative source-review license. It is **not** an open-source license.

You may view the code for evaluation and upstream contribution discussion, but no permission is granted to copy, modify, distribute, commercialize, or reuse the project without written permission. See `LICENSE`.
