# Testing notes

## Current environment caveat

This host has **Command Line Tools only** (no full Xcode). Neither
`XCTest` nor a complete `Testing` (swift-testing) module is available from
SwiftPM on a CLT install, so `swift test` can't run yet.

The plan's XCTest test file is committed as-is at
`Multi-CasualTests/Core/ModelsTests.swift` and will work unchanged the
moment Xcode is installed and selected with `sudo xcode-select -s
/Applications/Xcode.app`.

## Running the same assertions today

To prove the models behave correctly without Xcode, the same checks are
duplicated in an executable target:

```bash
swift run ModelsValidator
```

Expected output:

```
ok  test_issue_decodesFromJSON
ok  test_comment_decodesFromJSON
ok  test_pageResponse_decodesIssuesKey
ok  test_issueStatus_allCases_haveDisplayName

19 assertions passed, 0 failed
All tests passed.
```

`ModelsValidator` mirrors every assertion in `ModelsTests.swift`, so once
Xcode is available and `swift test` can build, both test paths will stay
in sync.

## Once Xcode is installed

```bash
swift test            # runs Multi-CasualTests with XCTest
swift run ModelsValidator   # still works, same assertions
```
