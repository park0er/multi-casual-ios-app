# PAR-73 Plan — Post-Login Stability + Feature Parity

_Author: RollieCC (agent). Last updated: 2026-04-23._
_Tracks: [PAR-73](https://multica.ai/issue/PAR-73) — 核心功能：Issue 列表 & 详情页._

---

## 0. Exec summary

Parker got past login, but the app-behind-login has **3 hard bugs, 2 missing features, and 2 enum-level data bugs** — plus a cross-cutting pattern bug I found during the audit. This plan fixes them in 3 phases, in order of blast radius. Phase 1 unsticks the app; Phase 2 makes it usable; Phase 3 closes feature parity with desktop.

| Phase | Scope | Fixes/adds | Est. time |
|---|---|---|---|
| **1. Unstick** | `PaginatedLoader` retry loop, Inbox/Projects/Detail shape bugs, error UX | B1, B2, B3, P1, V2 | ~3 h |
| **2. Usability** | Workspace switching + persistence, enum parity | F1, V1, V2 polish | ~2 h |
| **3. Parity** | Full Create Issue form (9 fields, desktop-complete) | F2 (+ new `listMembers`/`listAgents` endpoints) | ~4 h |

Evidence backing every claim is file:line referenced. If any table entry is wrong, please call it out.

---

## 1. Bug triage

### B1. Inbox tab spins forever

**Symptom.** Parker: "收件箱 (Inbox) 一直在转圈."

**Root causes (two, ordered by likelihood):**

1. **Pattern bug: `PaginatedLoader` infinite retry on decode error.**
   - `InboxView.swift:23-25` renders `ProgressView().onAppear { Task { await vm.loadNext() } }` as the tail-of-list more-indicator whenever `loader.hasMore == true`.
   - `PaginatedLoader.swift:9` initializes `hasMore = true`. `PaginatedLoader.swift:17-24` updates `hasMore` **only on success**; on throw, it stays `true`.
   - `InboxViewModel.swift:20-22` catches the error and stuffs it into `lastError`. **No view reads `lastError`.**
   - Net: 0 items rendered + tail spinner rendered + `.onAppear` re-fires → infinite loop. User sees an eternal spinner.

2. **Shape bug in `listInbox`.** The same class as the `listWorkspaces` fix in PAR-72.
   - `APIClient.swift:217` decodes response as `PageResponse<InboxItem>`.
   - `PageResponse.knownKeys` (`PageResponse.swift:8-10`) includes `"inbox"`. If backend returns `{inbox:[...]}`, this works.
   - If backend returns a **bare array** like `/api/workspaces` did, decode throws `keyNotFound` → triggers the retry loop above.

**Fix plan:**
- **Primary:** Fix `PaginatedLoader` to stop retrying on throw (see P1 below). This alone converts an invisible infinite loop into a one-shot visible error.
- **Secondary:** Make `PageResponse` accept a bare `[T]` as a valid shape. Small change in `PageResponse.init(from:)` — try `decoder.singleValueContainer().decode([T].self)` first, fall through to keyed container. Handles inbox / projects / any future endpoint without per-call per-array bespoke handling.
- **Verification:** Run in Simulator, open Inbox, either (a) items render, or (b) a clear error shows "Couldn't parse server response …" with the actual failing JSON path. Either outcome is a win over the current infinite spinner.

---

### B2. Projects tab spins forever

**Symptom.** Parker: "Projects 菜单也在转圈."

**Root causes (two, one of which is genuinely new):**

1. **Same pattern bug as B1** — `ProjectsView.swift:25` has the identical `hasMore`-tail-spinner + `.onAppear { loadNext() }` construction.

2. **`currentWorkspace` nil guard produces silent infinite spinner.**
   - `ProjectsViewModel.swift:18-19`: `guard let wsId = authSession.currentWorkspace?.id else { return }`.
   - If `AuthSession.currentWorkspace` is nil after login (AuthSession.swift:52 defaults to `workspaces.first` — nil if no workspaces), `loadNext` returns without touching state.
   - `hasMore` stays `true`, 0 items, tail spinner re-fires `loadNext` → silent infinite spinner without even touching the network.
   - **This is also why workspace switching is important (see F1)** — absence of a switcher + persistence means "which workspace are we loading projects for" is brittle.

3. **Same shape bug as B1** — `listProjects` at `APIClient.swift:226` returns `PageResponse<Project>`; `"projects"` is in `knownKeys`, but backend might return bare array.

**Fix plan:**
- P1 (loader fix) + shape-tolerance on `PageResponse` handles #1 and #3.
- For #2: promote the guard to a visible state. If `currentWorkspace == nil`, render a `ContentUnavailableView` with "Pick a workspace in Settings →" — not a silent spinner.
- **Verification:** Simulator smoke, same as B1.

---

### B3. Issue Detail page spins / shows nothing

**Symptom.** Parker: "点开 Issue 进详情页 又是在转圈，什么都没有."

**Root causes:**

1. **`loadIssue` shape bug.** `APIClient.swift:176` decodes `getIssue` as a bare `Issue`. If backend wraps it as `{issue: {...}}`, decode throws; `vm.issue` stays `nil`; `IssueDetailView.swift:40` renders only the comment area, nothing above. Not a spinner per se, but "看起来什么都没有."

2. **`loadAgentRuns` shape bug.** `APIClient.swift:203-207` hand-rolls `RunsResponse { runs: [AgentTask] }`. Unlike `PageResponse`, this has **zero tolerance** — if backend returns `{task_runs:[...]}`, `{items:[...]}`, or a bare array, decode throws. Error is swallowed with `try?` at `IssueDetailViewModel.swift:43`, so `agentRuns` silently stays `[]` — but if that throw happens, the "runs" section just looks empty, it doesn't spin.

3. **Comment pagination tail-spinner** (same pattern bug as B1/B2) — `IssueDetailView.swift:45-47` has the same `hasMore`-tail-spinner retry loop. **This is the actual "转圈" you're seeing in detail view**, triggered by `listComments` if its shape is wrong.

4. **`listComments` shape check.** `APIClient.swift:185` → `PageResponse<Comment>`; `"comments"` is in `knownKeys`. Low risk assuming backend uses that envelope.

**Fix plan:**
- P1 + shape-tolerance → kills the tail-spinner on comments.
- Add proper error rendering on `IssueDetailView` so if `loadIssue` throws, user sees "Couldn't load issue (…)" instead of an empty page.
- Migrate `RunsResponse` and `MessagesResponse` (APIClient.swift:209-213, same brittle pattern) onto the tolerant `PageResponse` flavor.
- **Verification:** Open any issue. Expect: title + description + status + priority + assignee header, comments list below, plus a clear error message if any endpoint shape is off.

---

### P1. Cross-cutting: `PaginatedLoader` retry-on-throw loop

**Not on Parker's original list — this is the bug the audit surfaced.**

The loop affects: **Inbox, Projects, IssueList, IssueDetail comments** — every paginated view. Fixing it at the loader level hardens all four simultaneously.

**Change:** In `PaginatedLoader.loadNext`, wrap the throw so that on error we set `hasMore = false` and re-throw. The caller VM still captures the error into its `lastError`, but the tail spinner stops retriggering.

**Bonus change:** Views should render `lastError` — one inline `Text(vm.lastError?.localizedDescription ?? "").foregroundStyle(.secondary)` below the list, under a "Retry" button that calls `vm.loader.reset()` + `vm.loadNext()`. Ten lines of UI per view, converts silent failures into actionable ones.

---

### V2. Silent error UX everywhere

**Not on Parker's original list — also from the audit.**

Every list VM (Inbox, Projects, Issues, IssueDetail) writes an `error`/`lastError` field that no view reads. `APIError.errorDescription` (APIClient.swift:241-297) already produces excellent diagnostic strings including the decode-failure JSON path. They're generated and thrown away.

**Fix:** Add a tiny reusable `ErrorRow` SwiftUI view that takes `(error: Error?, retry: () async -> Void)` and renders either nothing (no error) or a red text + retry button. Wire it into Inbox, Projects, IssueList, IssueDetail.

---

## 2. Features

### F1. Workspace picker in Settings

**Current state.** `SettingsView.swift:21-23` shows `LabeledContent("Workspace", value: ws.name)` — a **read-only text row**. No tap, no menu. `AuthSession` has no `setWorkspace` method and no persistence; on every launch it resets to `workspaces.first` (AuthSession.swift:52).

**Desired behavior (from Parker):** "必须能选、能切，持久化选中的 workspace，后续所有业务调用都用这个选中的 workspace_id."

**Design:**

1. **Data layer — `AuthSession`:**
   - Add `@Observable var workspaces: [Workspace] = []` (currently only `currentWorkspace`; the list is thrown away after `restore`).
   - Add `func setWorkspace(_ workspace: Workspace)` that updates `currentWorkspace` + writes `workspace.id` to UserDefaults under key `"selectedWorkspaceId"`.
   - In `restore(using:)`, after fetching `workspaces`, read UserDefaults — if there's a saved ID and it's in the fetched list, pick it; else fall back to `.first`.
   - Logout clears the UserDefaults key.

2. **UI layer — `SettingsView`:**
   - Replace the `LabeledContent` row with a `Picker("Workspace", selection: $selectedId)` bound via `authSession.workspaces`. `onChange` of selection → `authSession.setWorkspace(selectedWorkspace)`.
   - Display name + issue prefix in each row (so "AATest (AAT)" rather than just "AATest").

3. **Refresh downstream VMs on switch.**
   - `ProjectsViewModel`, `IssueListViewModel`, `InboxViewModel` all read `authSession.currentWorkspace`. On change, their caches are stale.
   - Simplest: observe `currentWorkspace.id` via `.onChange(of: authSession.currentWorkspace?.id)` in each View, call `vm.reset()` + `vm.loadNext()`.
   - Cleaner: teach `DataStore` to invalidate all workspace-scoped caches on workspace change. Can do this later; start with the simpler per-view `.onChange` hook.

**Estimate:** ~1 h including persistence + VM refreshes.

---

### F2. Create Issue — full field parity

**Current state.** `IssueCreateSheet.swift` has only `title` + `description` (state at L10-11, sections at L20-23, submit at L39-50). Desktop has **9 fields**. This is the biggest gap in the app right now.

**Desktop authority (from reverse-engineering `/Applications/Multica.app/Contents/Resources/app.asar`, `@multica/views/modals/create-issue.tsx`):**

| # | Field | Widget | Required | Default | iOS status |
|---|---|---|---|---|---|
| 1 | `title` | text field | ✅ | — | ✅ exists |
| 2 | `description` | multiline markdown | ❌ | "" | ✅ exists |
| 3 | `status` | picker | ❌ | `"todo"` | ❌ missing |
| 4 | `priority` | picker | ❌ | `"none"` | ❌ missing |
| 5 | `assignee_type` + `assignee_id` | combined picker (Members + Agents) | ❌ | unassigned | ❌ missing + **needs 2 new endpoints** |
| 6 | `due_date` | date picker | ❌ | null | ❌ missing |
| 7 | `project_id` | picker | ❌ | null | ❌ missing |
| 8 | `attachment_ids` | upload via description | ❌ | [] | ❌ missing — defer to follow-up issue |
| 9 | `parent_issue_id` | not a picker — set by caller when opening as "sub-issue" | ❌ | null | ❌ missing — defer; no sub-issue UX in iOS v1 |

**Request body shape (verified from `@multica/core/types/api.ts:6-17`):**
```json
{
  "title": "...",
  "description": "...",          // optional, markdown
  "status": "todo",               // optional, backend defaults
  "priority": "none",             // optional, backend defaults
  "assignee_type": "member|agent", // optional
  "assignee_id": "uuid",          // optional
  "due_date": "ISO8601",          // optional
  "project_id": "uuid",           // optional
  "parent_issue_id": "uuid",      // optional
  "attachment_ids": ["uuid"]      // optional
}
```

**API client gaps (blocking F2):**

- **`listMembers(workspaceId:)` — does not exist.** Need: GET `/api/workspaces/{id}/members` → `[Member]` (shape TBD; cross-reference desktop `@multica/core/api/client.ts`).
- **`listAgents(workspaceId:)` — does not exist.** Same drill: GET `/api/workspaces/{id}/agents` → `[Agent]`.
- **`Member` / `Agent` structs — don't exist** in `Models.swift`. Need adding.
- Existing `createIssue` only sends `{title, description, workspace_id}` (APIClient.swift:158-166). Expand the private request struct.

**v1 scope (this plan):**
- Fields 1–7 in the form. (Attachments 8 + sub-issue 9 deferred to follow-up issues.)
- Combined AssigneePicker like desktop (single search input, two sections: Members / Agents), or two simpler pickers if a combined one is more work than v1 deserves. **Lean toward combined — matches desktop UX Parker is used to.**
- No draft persistence for v1 (desktop uses Zustand + localStorage — skip in iOS v1 to keep scope small).

**Open question for Parker:**
- **Q1.** Do you want fields **1–7 all at v1**, or is there anything here you'd cut to ship faster? Default assumption: all seven.
- **Q2.** For Assignee, do you want the full desktop behavior (agent `visibility === "private"` gating based on current user's role / agent ownership)? Default: **skip the gating for v1** — show all agents, let backend reject if needed. Saves significant work.

**Estimate:** ~3 h for fields 3–7 + `listMembers` / `listAgents` + Member/Agent structs + picker UIs. Add ~1 h if we do the gating. Attachments (field 8) is its own ~2 h task and probably deserves a separate issue.

---

## 3. Enum validation

### V1. `IssueStatus` parity

**Desktop (authoritative, from `@multica/core/types/issue.ts:1-8`):**
`backlog | todo | in_progress | in_review | done | blocked | cancelled` — **7 cases.**

**iOS (`Models.swift:66-117`):** `todo, inProgress (="in_progress"), inReview (="in_review"), done, blocked, unknown` — **5 cases + fallback.**

**Missing:** `backlog`, `cancelled`. iOS safely maps them to `.unknown` via the lenient `init(from:)` at L76-79, so nothing crashes — but:
- Issues with status `backlog` render as "Unknown" in list/detail.
- Issues with status `cancelled` also render as "Unknown" instead of being styled as cancelled.
- Board view grouping will collapse both into a "Unknown" column.

**Fix:** add `backlog` and `cancelled` cases with matching `displayName` + `icon` + sort-order slot. Total diff: ~15 lines in Models.swift.

Desktop sort order for reference: `BOARD_STATUSES` excludes `cancelled`; `STATUS_ORDER = [backlog, todo, in_progress, in_review, done, blocked, cancelled]`. Should align iOS `Comparable` impl to this — currently L81-93 has `blocked` at index 0 which is backwards from desktop intuition (blocked is usually "needs attention," not lowest priority).

---

### V2. `IssuePriority` parity — **active bug**

**Desktop (authoritative, from `@multica/core/types/issue.ts:10`):**
`urgent | high | medium | low | none` — **5 cases.**

**iOS (`Models.swift:119-139`):** `urgent, high, medium, low, noPriority (= "no_priority"), unknown`.

**BUG.** iOS's raw value is `"no_priority"` — but backend/desktop uses `"none"`. Every time backend sends `"priority":"none"` (which is the default for new issues), iOS decodes to `.unknown` via the lenient fallback. **Every default-priority issue misrenders as "Unknown".**

This is silent data corruption the whole time, hidden by the lenient decoder. Not on Parker's original list, found during audit.

**Fix:** change `case noPriority = "no_priority"` → `case none` (rawValue defaults to `"none"`). Update switch statements in `displayName` etc.

---

## 4. Work breakdown + order

### Phase 1 — Unstick (priority: critical)

1. **P1** — Fix `PaginatedLoader` retry loop. (~20 min, hardens 4 views)
2. **V2 bug** — Priority `"none"` rawValue fix. (~5 min, blocks correct rendering everywhere)
3. **B1/B2 shape tolerance** — `PageResponse` accepts bare array. (~20 min)
4. **B3** — Migrate `RunsResponse` / `MessagesResponse` onto tolerant decoder. (~20 min)
5. **V2 UX** — `ErrorRow` component + wire into all list views. (~40 min)
6. **Simulator smoke test** — all four tabs (Inbox / Issues / Projects / Settings), open an issue, send a comment. (~30 min)

**End-of-phase state.** App no longer spins forever anywhere. If any endpoint is still shape-mismatched, the user (Parker) sees the exact decoding error with the failing JSON path — which is the worst case. No more silent infinite loops.

### Phase 2 — Usability

1. **V1** — Add `backlog` / `cancelled` to `IssueStatus`; align sort order. (~15 min)
2. **F1** — Workspace picker + persistence + VM refreshes. (~1 h)
3. Re-run Simulator smoke, verify workspace switch → data refreshes correctly. (~15 min)

### Phase 3 — Create Issue parity (biggest chunk)

1. Add `Member` / `Agent` structs to Models. (~15 min)
2. Add `listMembers` / `listAgents` to APIClient + tests. (~30 min)
3. Build 5 new pickers: StatusPicker, PriorityPicker, AssigneePicker (combined), DueDatePicker, ProjectPicker. (~1.5 h)
4. Wire into `IssueCreateSheet` + expand `createIssue` API call. (~45 min)
5. Simulator smoke — create one issue with every field populated; verify it appears correctly in desktop too. (~30 min)

**Total estimate:** ~9 h wall time for everything. Realistically across multiple re-dispatched sessions.

---

## 5. Deliverables per phase

Each phase = one PR-sized commit cluster on `main` (no branching; Parker's solo + I'm the only agent touching this repo). Each phase ends with:

1. `swift test` green (adjusted for new tests).
2. New integration smoke (where applicable) — e.g. for F1, add a test asserting UserDefaults persistence round-trips.
3. Simulator smoke checklist executed by Parker, screenshotted if anything looks off.
4. A comment on PAR-73 summarizing what landed + what's next.

---

## 6. Open questions (unblock before Phase 2/3 start)

1. **F2 field scope.** Fields 1–7 all at v1, or cut any? (Default: all seven, skip attachments 8 and sub-issue 9.)
2. **F2 assignee gating.** Match desktop's private-agent visibility rules, or skip for v1? (Default: skip; show all, backend enforces.)
3. **V1 sort order.** Flip iOS `Comparable` to match desktop `[backlog, todo, in_progress, in_review, done, blocked, cancelled]`? (Default: yes, align.)
4. **PLAN.md location + format.** This doc lives at `~/Coding/Multi-Casual/PLAN.md`. Keep it here + update in place as phases land? Or move to `docs/PLAN-PAR-73.md` and start a `docs/` convention?

No answers needed for Phase 1 to proceed — I can start Phase 1 immediately on approval. Phase 2/3 scoping depends on answers to 1–3.

---

## 7. Files touched (preview)

**Phase 1:**
- `Multi-Casual/Core/Cache/PaginatedLoader.swift` — retry loop fix
- `Multi-Casual/Core/Network/PageResponse.swift` — bare-array tolerance
- `Multi-Casual/Core/Network/APIClient.swift` — RunsResponse/MessagesResponse migration
- `Multi-Casual/Models/Models.swift` — `IssuePriority.none` rawValue fix
- `Multi-Casual/Shared/ErrorRow.swift` **(new)** — error UI component
- `Multi-Casual/Features/{Inbox,Projects,Issues}/*View.swift` — wire ErrorRow
- `Multi-CasualTests/Core/PaginatedLoaderTests.swift`, `PageResponseTests.swift` — regression coverage

**Phase 2:**
- `Multi-Casual/Core/Auth/AuthSession.swift` — `setWorkspace` + persistence
- `Multi-Casual/Features/Settings/SettingsView.swift` — Picker
- `Multi-Casual/Models/Models.swift` — `IssueStatus` cases + sort order

**Phase 3:**
- `Multi-Casual/Models/Models.swift` — `Member`, `Agent` structs
- `Multi-Casual/Core/Network/APIClient.swift` — new endpoints + request body expansion
- `Multi-Casual/Features/Issues/Pickers/` **(new)** — 5 picker views
- `Multi-Casual/Features/Issues/IssueCreateSheet.swift` — full form

---

_Evidence basis for every claim in this plan is file:line-referenced above. Audit transcripts from 2026-04-23 are on request._ 🐱
