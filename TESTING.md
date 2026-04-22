# Testing

Three-layer test pyramid, per PAR-79.

| Layer | Command | Where it runs | What it covers |
|---|---|---|---|
| Core | `swift test` | macOS 14+ (no Simulator needed, thanks to `.macOS(.v14)` in `Package.swift`) | Models, Keychain, APIClient, PaginatedLoader, DataStore, PKCE |
| Validator | `swift run ModelsValidator` | Any Swift toolchain (CLT is enough) | Same Models / API shape assertions as Core, minus XCTest |
| Simulator | `xcodebuild test -scheme Multi-Casual-Package -destination 'platform=iOS Simulator,id=…'` | Xcode + iOS Runtime | Same Core suite compiled for iOS + catches iOS-only regressions (SwiftUI type inference, platform-specific API) |

## Commands

```bash
# 1) Core — fastest, no Simulator
swift test

# 2) CLT fallback — works even without XCTest
swift run ModelsValidator

# 3) iOS Simulator — pick an available iPhone (see `xcrun simctl list devices available`)
xcodebuild test \
  -scheme Multi-Casual-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath /tmp/Multi-Casual-iOS-Sim.xcresult
```

## Notes / gotchas

- **Keychain tests skip on iOS Simulator.** `KeychainStoreTests` calls `throw XCTSkip` under `#if os(iOS)` because SecItem APIs return `-34018 errSecMissingEntitlement` unless the test bundle runs inside a signed host app providing `keychain-access-groups`. macOS `swift test` has no such restriction, so the logic is fully exercised there. Once the Xcode app-wrapper lands with entitlements, flip the guard.
- **`App/` is excluded from the SPM library target.** The `@main struct Multi-Casual: App` entrypoint collides with `ModelsValidator`'s `main.swift` at link time on iOS. `App/` sources move into the Xcode wrapper's app target; the SPM library stays platform-neutral.
- **Simulator OS version mismatch.** `simctl list runtimes` may report `iOS 26.4` while `xcodebuild` insists on the build-stamped `26.4.1`. Prefer passing the simulator UUID (`id=…`) over the `OS=` query.

## Runs

### 2026-04-21 — PAR-79 first green full run (persistent `~/Coding/Multi-Casual`)

| Layer | Result | Notes |
|---|---|---|
| `swift test` | **22/22 pass** in ~0.06s | APIClient (4), DataStore (3), Keychain (4), Models (4), PKCE (3), PaginatedLoader (4) |
| `swift run ModelsValidator` | **19/19 pass** | CLT fallback |
| `xcodebuild test` (iPhone 17 Pro, iOS 26.4.1) | **18 passed, 4 skipped, 0 failed → Test Plan: Passed** | 4 skipped = Keychain (entitlement) |

Environment: Xcode 26.4.1 (17E202), iOS 26.4 Runtime (26.4.1 build 23E254a), Apple Silicon arm64.

First Simulator-green run lived in the ephemeral agent worktree; the code fixes that got there shipped as commit `d2840b1 build: iOS compile fixes (App/ exclusion, ShapeStyle, keychain test skip)`:

1. `IssueDetailView.swift:100` — `foregroundStyle(… ? .secondary : .blue)` hit a type ambiguity between `HierarchicalShapeStyle` and `Color` on iOS 26. Pinned both branches to `Color.` explicitly.
2. `Package.swift` — `App/` excluded from `Multi-Casual` target sources to prevent duplicate `_main` symbol at iOS link time (`@main` in App + `main.swift` in ModelsValidator).
3. `KeychainStoreTests.swift` — `setUpWithError` throws `XCTSkip` on iOS with reason; macOS still runs the real Keychain path.

## Features / ViewModel layer — still TODO

Per PAR-79, we still need ViewModel-level tests for `LoginViewModel`, `InboxViewModel`, `IssueListViewModel`, and `IssueDetailViewModel`. These should run on both `swift test` (macOS) and the Simulator destination once added, since they don't touch Keychain.
