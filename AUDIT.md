# Senior-Grade Ledger

## Remediation — 2026-08-02 @ main (post CLEAN-001..012, MAINT-001, OPS-004)

Mode: fix
Score: not re-scored — this was a remediation pass, not a grade pass. A fresh
grade should be run against this commit before any release claim is made.
Caps: race-prone async **removed**; mandatory CI **partially removed** (see
below); production observability **still applies**.

Fixed — each in its own PR, with regression tests, mutation-verified where a
behavioural claim was made:

- CLEAN-001 (#58) rotation anchored to a global epoch, not the user's start date
- CLEAN-002 (#59) enrollment enforced as a completion and calendar boundary
- CLEAN-003 (#60) over-long journals rejected, never silently truncated
- CLEAN-010 (#61) archive declares iPhone-only, asserted from the built plist
- CLEAN-009 (#62) unbounded completion query; Journey and BadgeService now agree
- CLEAN-006 (#63) notification chain guarded against concurrent linking
- CLEAN-004 (#64) typed persistence errors, atomic completion+badges, store recovery
- CLEAN-005 (#65) civil day frozen at write time, with a tested V1->V2 migration
- CLEAN-012 (#66) dead constants deleted, survivors wired to their use
- CLEAN-008 (#67) UI tests fail when the behaviour they name breaks
- MAINT-001 (#68) Swift 6 language mode, zero project-owned warnings
- CLEAN-007 (#69, #70) pinned reproducible tooling, `make ci`, GitHub Actions
- CLEAN-011 (#71) one current document set; everything else marked historical
- OPS-004 (#72, #73) accessibility audit in CI, and the seven screens it failed

Deferred — none of these can be closed from a development machine; all four need
hardware, an App Store Connect session, or a product decision. Owner: maintainer.

- OPS-001 (#52) signed TestFlight / App Store validation on a physical device
- OPS-002 (#53) **partially addressed.** `docs/ship/OPERATIONS.md` now carries
  the triage table, rollback procedure, release checklist, and a scripted
  recovery drill. Three decisions remain open and are marked in the document:
  crash-reporting approach, support address, and owner. The cap stands until
  they are answered.
- OPS-003 (#54) **partially addressed.** The store now opens at
  `FileProtectionType.complete` rather than the OS default, a privacy manifest
  ships declaring no tracking, no collection, and the UserDefaults required
  reason, and `docs/ship/DATA_PROTECTION.md` records the policy. On-device
  confirmation still outstanding; the simulator has no hardware key hierarchy
  and does not report the attribute back.
- OPS-005 (#56) performance budgets measured on representative hardware

Accepted risks:

- Branch protection is unavailable on this repository's plan; both the
  protection and rulesets APIs return 403. CI runs on every pull request and
  every push to main, but cannot block a merge. Enforced by the documented
  policy in `docs/ship/MERGE_CHECKLIST.md` until the plan allows otherwise.
  Making the repository public, or upgrading to Pro, would close this.
- Two narrow accessibility-audit exclusions, documented at the point of
  exclusion: issues the audit cannot attribute to an element, and elements
  resting under the translucent tab bar.
- **Hosted CI is manual-only, and merge enforcement is policy — accepted by the
  maintainer, 2026-08-02.** GitHub-hosted macOS runs stopped being scheduled
  part-way through this pass (jobs fail in ~2s with no runner assigned). The
  workflow is proven — runs 30774253168, 30774801972 and 30775380483 completed
  every job green — and is kept intact on `workflow_dispatch`. It does not
  trigger automatically because a check that always fails is worse than no
  check: it teaches everyone to ignore red. Combined with branch protection
  being unavailable on this plan, this means **nothing mechanically prevents a
  merge past a failing gate**. `make ci` on a developer machine is the gate, by
  decision. Revisit if the repository goes public or a runner is self-hosted.

Cap status, stated precisely because the difference matters:

| Cap | Status |
|---|---|
| Unbounded or race-prone async processing (B) | **Removed.** Swift 6 language mode, zero project-owned warnings under complete concurrency checking, enforced in CI. The notification chain's ordering invariant is now mechanically guaranteed and stress-tested. |
| No mandatory CI (B) | **Partially removed.** Every check is reproducible from a bare checkout and runs on every PR. It is not *mandatory* in the platform sense — the plan does not permit branch protection — so the requirement is currently policy, not mechanism. |
| No production health/shutdown/observability story (B+) | **Still applies.** There is still no way to learn that the app crashed in the field, no named support owner, no triage runbook, and no rollback procedure (#53), and no signed build has ever been validated (#52). |

Verification at this commit:

```
make ci                      -> All checks passed
  generated project drift    -> none
  content validation         -> 365 challenges valid
  swiftlint --strict         -> 0 violations in 86 files
  unit + integration tests   -> 246 passing
  Services/ViewModels covg.  -> 92.99% (862/927 lines), floor 90%
  UI tests                   -> 44 passing, 1 skipped (month-boundary guard)
  accessibility audit        -> 8 screens, 0 issues
  static analyzer            -> succeeded
  strict concurrency         -> 0 project-owned warnings
  release archive            -> succeeded; UIDeviceFamily [1], no iPad orientations
```

Baseline for the next audit: this commit. The next grade pass should diff from
here and should expect the operations cap to be the binding constraint.

---

## Audit — 2026-08-02 @ 9ffe014f3140ac1bd73014ce36dd94df5c26f44d

Mode: grade  
Score: 77/100 (C+)  
Caps applied: unbounded or race-prone async processing (B); no mandatory CI (B); no production health/shutdown/observability story (B+)  
Fixed: none — grade mode is read-only  
Deferred: CLEAN-001 through CLEAN-012 — first audit; remediation requires a separate fix pass; owner: maintainer  
Accepted risks: none recorded by this audit

Baseline: 2026-08-02, branch `main`, commit `9ffe014f3140ac1bd73014ce36dd94df5c26f44d`, initially clean worktree. Toolchain: macOS 26.5, Xcode 26.6 (17F113), Swift 6.3.3, XcodeGen 2.46.0. This is the first `AUDIT.md`; the review therefore covers the full repository and Git history rather than a diff from a prior audit.

## 1. Executive verdict

**77/100 (C+). Previous grade: none; movement: N/A. Production-ready: no. Senior-quality: no.** The app is a credible, functional pre-release build, but it is not yet safe to market or operate as the documented product.

Strongest qualities:

1. The real release, archive, unit/integration, UI, content-validation, and simulator-launch paths execute successfully.
2. The local-only privacy surface is small: no account, server, tracking SDK, third-party package, or secret was found.
3. The service/view-model logic is unusually well unit-tested for a project of this size: 179 unit/integration tests passed and aggregate Services/ViewModels line coverage is 95.3%.

Largest risks:

1. The user-relative rotation contradicts the core and App Store promise that every user gets the same challenge on a calendar date.
2. Enrollment is not an eligibility boundary: a new user is shown pre-install days as missed and can complete days from before joining.
3. Journal content can be silently truncated, while broader persistence failures are hidden or split across non-atomic saves.

Finding counts: P0 0, P1 3, P2 8, P3 1. Fix today: CLEAN-001, CLEAN-002, CLEAN-003.

Executed evidence:

- `xcodegen generate` succeeded and did not change the committed project.
- Release simulator build succeeded; device archive succeeded; Xcode static analysis succeeded. The archive emitted one iPad-orientation warning.
- 179/179 unit/integration tests passed. Unit coverage: app 36.84% overall; Services/ViewModels 668/701 lines (95.3%), with `NotificationService` at 87.7%.
- 23/23 UI tests passed through real simulator launches and interactions.
- The release app installed, launched as PID 24554, remained alive for inspection and screenshot, rendered onboarding, and terminated cleanly. Host/port and HTTP health checks are N/A for a native offline iOS app.
- `scripts/validate_challenges.py` passed: 365 records, identical production/test copies, five valid batches. Both Python scripts compiled; the release app is 4.6 MB in the simulator and the unsigned device archive is 9.1 MB.
- Full-tree and full-patch-history high-confidence secret scans returned no matches. No sensitive filenames were found in history.
- Dependency install/audit is N/A: the Xcode project has no third-party package products or package lockfile.
- SwiftLint was **Unverified** because `swiftlint` is not installed and the repository has no reproducible tool bootstrap.
- GitHub reports zero Actions workflows. Branch-protection inspection returned GitHub's 403 indicating the feature is unavailable for this private repository/account tier.
- App Store upload/validation, signing, TestFlight, device performance, accessibility, and crash-recovery behavior remain **Unverified** because they were not authorized or no reproducible command exists.

## 2. Release blockers

| ID | Evidence | Impact | Reproduction |
|---|---|---|---|
| CLEAN-001 | `ChallengeService.swift:60` derives rotation from `userStartDate`, while `APP_STORE_LISTING.md:29` promises “the same one every user receives.” | The public product claim becomes false as soon as users have different tenure-year offsets. | Construct services with start dates 2025-01-01 and 2026-01-01; query 2026-06-15. Existing test `testChallengeForDateAppliesYearOffsetFromUserStartDate` proves the IDs differ. |
| CLEAN-002 | `ChallengeService.swift:67` validates only the three-day grace window, not `userStartDate`; `CalendarViewModel.swift:100` marks every prior day missed/recoverable. | A first-day user can backfill pre-enrollment challenges and starts with misleading missed history. | `AppEnvironmentTests.testGracePeriodCompletionOnCalendarRefreshesJourney` creates a profile “now,” injects an earlier app date, completes an even earlier day, and passes. |
| CLEAN-003 | `ChallengeService.swift:79` silently applies `prefix(2000)` while `CompletionSheetView.swift:18` accepts unbounded text and `DailyWalkView.swift:66` dismisses the sheet after calling a non-result-returning view-model method. | Users can believe a private journal was preserved when its tail was discarded. | Paste 2,001 non-whitespace characters, complete, fetch `CompletedChallenge`; only 2,000 persist and no UI warning is shown. |

## 3. Grading table

| Category | Weight | Raw | Weighted | Previous | Change | Evidence, ceiling, and 90+ requirement |
|---|---:|---:|---:|---:|---:|---|
| Product coherence | 5% | 70 | 3.5 | N/A | N/A | Daily, calendar, journey, settings, and onboarding form a usable flow. The shared-challenge promise conflicts with tenure rotation, and documented v1 export/profile/badge-art scope is unresolved. Reach 90 by choosing one schedule contract, enforcing enrollment semantics, and reconciling the shipped scope. |
| Architecture | 15% | 78 | 11.7 | N/A | N/A | A small composition root and protocol-backed services give clear direction. Profile ownership is duplicated, actor ownership is implicit, and persistence invariants are spread across services. Reach 90 by centralizing profile/persistence ownership, transactions, and actor boundaries. |
| Correctness | 15% | 76 | 11.4 | N/A | N/A | Release build, archive, analyzer, 202 tests, rollover, grace, badges, and content checks pass. Pre-enrollment completion, journal truncation, timezone identity, and the 2030 query horizon prevent a higher score. Reach 90 with explicit date identity and error/result contracts plus regression tests. |
| Security and privacy | 15% | 90 | 13.5 | N/A | N/A | No secrets, remote input, auth surface, tracking, third-party SDKs, unsafe execution, or journal logging was found; notifications contain generic text. App Store privacy-manifest acceptance and on-device file-protection behavior remain unverified. Preserve 90+ with an upload validation and a documented sensitive-journal storage policy. |
| Reliability and concurrency | 10% | 68 | 6.8 | N/A | N/A | Notification intent is serial and content loading fails closed. Completion/badge persistence is non-atomic, save failures are suppressed, startup can crash-loop, timezone changes are not modeled, and strict concurrency reports reachable data-race risks. Reach 90 with atomic/reconcilable writes, surfaced recovery, actor isolation, and failure-timeline tests. |
| Testing and AI quality | 15% | 84 | 12.6 | N/A | N/A | 179 unit/integration and 23 UI tests pass; Services/ViewModels coverage is 95.3%. Several UI tests are vacuous or assert only section existence; no failure-injection, timezone, long-journal, archive-validation, or CI enforcement exists. There is no runtime AI component. Reach 90 by making UI assertions behavioral and enforcing all suites in CI. |
| Maintainability | 10% | 83 | 8.3 | N/A | N/A | The codebase is compact and readable, static analysis passes, and dependencies are minimal. Swift 6 strict concurrency warnings, dead symbols/constants, duplicated profile bootstrap, and non-reproducible lint hold it back. Reach 90 with Swift 6-clean isolation, dead-code cleanup, and pinned tooling. |
| Operations and observability | 10% | 62 | 6.2 | N/A | N/A | A human TestFlight runbook exists and the device archive builds. There is no CI, automated signed/archive validation, release automation, crash-triage evidence, recovery path, or support URL; iPad configuration warns. Reach 90 with mandatory CI, signed upload validation, crash/support ownership, and a tested release runbook. |
| Documentation and governance | 5% | 66 | 3.3 | N/A | N/A | Privacy, licensing, content, and shipping notes are extensive. The architecture still describes CloudKit/three licensed translations, while launch checklists retain superseded blockers and the listing makes a false shared-schedule claim. Reach 90 by making one current source of truth and checking claims against executable behavior. |

Arithmetic score: 77.3, rounded to 77 (C+). The applied caps do not lower the arithmetic grade further.

## 4. Grade-cap analysis

| Cap | Applies? | Evidence |
|---|---|---|
| Secrets in tree/history or exploitable critical vulnerability → F | No | Full-tree/full-history high-confidence scan was clean; no Critical vulnerability was found. |
| Production build or artifact cannot start → C+ | No | Release build, device archive, simulator install, live launch, liveness check, screenshot, and termination passed. |
| Primary user workflow is broken → C | No | Onboarding, daily challenge, completion, calendar, journey, and settings execute; the release blockers are invariant and failure-path defects rather than total workflow failure. |
| Reachable Critical/High production vulnerability → C | No | No server, authentication, remote input, third-party dependency, or exploitable High security defect exists. |
| Known critical authorization/data-exposure problem → C+ | N/A | No account, authorization boundary, backend, or remote data serialization exists. |
| No runtime validation at trust boundaries → B− | N/A | The production bundle is signed/local and decodes through `Codable`; journal input is length-bounded at persistence. There is no remote/user-controlled mutation boundary beyond journal text. |
| Unbounded or race-prone async processing → B | **Yes** | `NotificationService.enqueue` mutates a `Task` chain without actor isolation; strict-concurrency diagnostics flag `ContentView.swift:37`, `NotificationService.swift:23`, and `:131` as future Swift 6 errors. |
| No mandatory CI → B | **Yes** | No workflow files exist and GitHub reports zero Actions workflows. |
| No realistic integration/browser coverage → B+ | No | Real integration tests and 23 simulator UI tests run, despite quality gaps in several cases. |
| No production health, shutdown, or observability story → B+ | **Yes** | Mobile health is N/A, but the equivalent release/crash/recovery story is manual and unverified; no CI, crash-triage evidence, or data-store recovery exists. |
| AI behavior lacks repeatable evaluation → B− for AI component | N/A | No runtime AI subsystem exists. Static AI-assisted content is bundled and has deterministic schema/copy validation plus documented human spot checks. |

Apple's current [required-reason API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) was checked. No App Store upload was performed, so privacy-manifest acceptance is explicitly unverified rather than assumed.

## 5. Component grades

| Component | Grade | Strongest attribute | Largest risk / what prevents A | Smallest change set to A |
|---|---:|---|---|---|
| iOS UI and product flow | 82 (B−) | Clean native flow and real UI execution | Pre-enrollment history and incomplete/stale documented scope | Enforce start boundary, surface journal errors/limits, complete accessibility/device QA |
| Scheduling/domain logic | 70 (C−) | Deterministic, heavily tested scheduling | Shared-date contract conflicts with user-relative year rotation | Choose global calendar-year rotation or change every product claim, then test two users |
| SwiftData persistence | 68 (D) | Small local model and successful relaunch test | Silent errors, crash-only startup, non-atomic completion/badges, no recovery | Persistence coordinator, typed errors, atomic/reconciliation path, uniqueness constraints |
| Notifications/concurrency | 72 (C−) | Stable identifiers and intended serial ordering | Serial chain itself is not isolated; strict concurrency warnings | Main-actor/actor isolation and simultaneous schedule/cancel tests |
| Privacy/security | 90 (A−) | Minimal local-only, dependency-free attack surface | File protection and App Store privacy validation unverified | Document protection class; validate signed upload/privacy report |
| Content pipeline | 91 (A−) | 365-row deterministic validator and identical copies | Validator is not CI-enforced; source-fetch rebuild is manual | Run validator in mandatory CI and pin/provenance source inputs |
| Tests and CI | 78 (C+) | High logic coverage and real UI target | Vacuous UI cases and zero CI | Behavioral UI fixtures, failure tests, required workflow |
| Release operations | 65 (D) | Archive and manual TestFlight runbook work | Unsigned/unuploaded path, iPad warning, no automation/support/crash loop recovery | CI archive, signed validation, support/crash ownership, orientation fix |
| Documentation/governance | 66 (D) | Strong privacy/licensing history | Multiple mutually inconsistent “current” documents | Current architecture/ADR plus one generated launch checklist |

## 6. Findings

### CLEAN-001 — User-relative rotation breaks the shared daily challenge contract

- Priority: P1. Confidence: High. Category: Product coherence / correctness. Effort: M.
- Location: `Faithfully/Services/ChallengeService.swift:56`, `Faithfully/Utilities/ChallengeScheduler.swift:25`, `PRD.md:88`, `docs/ship/APP_STORE_LISTING.md:29`.
- Exact evidence: `let offset = ChallengeScheduler.yearOffset(from: userStartDate, to: date)` and `index = ... + (yearOffset * 47)` versus “Challenge is the same for all users on the same calendar day.”
- Reproduction: run the existing year-offset service test or instantiate two services one tenure-year apart and query the same date; the test requires different challenge IDs.
- Impact: the defining shared-experience and ready-to-paste App Store claim becomes false for mature versus newer users.
- Root cause: “year” was modeled as tenure year even though shared scheduling requires a global calendar epoch.
- Remediation: choose the product invariant. Recommended: derive a global calendar-year offset from a fixed epoch; migrate no user data because only deterministic mapping changes. If tenure rotation is intentional, remove every shared-date claim and reassess the product premise.
- Acceptance: two users with arbitrary start dates receive the same challenge for every sampled calendar date; adjacent calendar years rotate; App Store copy and PRD agree.
- Existing issue: new; GitHub issue query returned no issues. Estimated grade impact: +4 to +6.

### CLEAN-002 — Enrollment date is not enforced as a completion or calendar boundary

- Priority: P1. Confidence: High. Category: Correctness. Effort: M.
- Location: `Faithfully/Services/ChallengeService.swift:64`, `Faithfully/ViewModels/CalendarViewModel.swift:100`, `Faithfully/App/AppEnvironment.swift:57`.
- Exact evidence: completion checks only `GracePeriod.canComplete(...)` and `!isCompleted(...)`; calendar classifies every past date as `.missedRecoverable` or `.missed`. The stored `userStartDate` is used only for rotation.
- Reproduction: the passing `AppEnvironmentTests.testGracePeriodCompletionOnCalendarRefreshesJourney` bootstraps a profile after its injected app date, then completes an earlier grace day and increments Journey.
- Impact: a new user begins with false missed history and can earn progress/streak credit for days before joining.
- Root cause: start date is treated as scheduler metadata, not a domain eligibility invariant.
- Remediation: reject `scheduledDate.startOfDay < userStartDate.startOfDay`; introduce a pre-enrollment/unavailable calendar state; prevent navigation/completion before enrollment.
- Acceptance: first-day UI has no missed pre-enrollment days; all pre-start completion attempts fail with a typed error; boundary tests cover install day, three days prior, month/year rollover.
- Existing issue: new. Estimated grade impact: +3 to +5.

### CLEAN-003 — Journal text is silently truncated after the user submits it

- Priority: P1. Confidence: High. Category: Correctness / data integrity. Effort: S.
- Location: `Faithfully/Services/ChallengeService.swift:78`, `Faithfully/Views/DailyWalk/CompletionSheetView.swift:18`, `Faithfully/Views/DailyWalk/DailyWalkView.swift:65`.
- Exact evidence: `String($0.prefix(Constants.maxJournalLength))` silently drops the suffix; the editor has no limit/counter and the sheet always clears its local text after `vm.complete` returns.
- Reproduction: submit 2,001 characters and fetch the saved row; length is 2,000 with no warning.
- Impact: private user-authored content is lost while the UI implies successful completion.
- Root cause: the persistence boundary mutates input instead of making the limit part of the UI contract.
- Remediation: enforce a visible character limit while editing or block submission; return a typed success/failure result before dismissing; add round-trip tests at 1,999/2,000/2,001 characters.
- Acceptance: the user can never submit unseen text that will be discarded, and failed saves preserve the draft.
- Existing issue: new. Estimated grade impact: +2 to +4.

### CLEAN-004 — Persistence has no coherent error or transaction contract

- Priority: P2. Confidence: High. Category: Architecture / reliability. Effort: L.
- Location: `Faithfully/App/FaithfullyApp.swift:17`, `Faithfully/App/AppEnvironment.swift:82`, `Faithfully/Services/ChallengeService.swift:89`, `Faithfully/Services/BadgeService.swift:57`, `Faithfully/ViewModels/SettingsViewModel.swift:96`.
- Exact evidence: startup uses `fatalError`; most fetches/saves use `try?`; completion is saved at `ChallengeService.swift:90` before badges are evaluated and saved separately at `BadgeService.swift:58`.
- Reproduction: make the store unavailable/full or terminate after completion save and before badge save. Settings can show changed values that were not persisted; completion can survive without its earned badge; corrupted store can crash-loop.
- Impact: false success, lost settings/badges, inconsistent state, and no user recovery.
- Root cause: services own ad hoc ModelContext calls rather than a transaction/recovery boundary.
- Remediation: centralize persistence, propagate typed errors, keep drafts on failure, atomically save completion plus awards or reconcile awards on launch, and provide store recovery/export guidance.
- Acceptance: injected fetch/save failures are tested; no `try? modelContext` remains on user mutations; interruption tests restore all invariants.
- Existing issue: new. Estimated grade impact: +4 to +7.

### CLEAN-005 — Calendar-day identity is timezone-dependent

- Priority: P2. Confidence: Med. Category: Reliability. Effort: L.
- Location: `Faithfully/Services/ChallengeService.swift:85`, `Faithfully/Services/ChallengeService.swift:98`, `Faithfully/Utilities/StreakCalculator.swift:5`.
- Exact evidence: `scheduledDate.startOfDay` persists an absolute `Date`, then later queries and streaks reinterpret it through the current `Calendar.current`; no timezone or civil-day key is stored.
- Reproduction: complete near midnight in one timezone, change the device timezone across the date line, relaunch, and inspect calendar/streak day grouping.
- Impact: a completion can move calendar days or disappear from the queried interval after travel, breaking streak and completion identity.
- Root cause: a civil-day domain key is represented only by an instant whose interpretation changes with timezone.
- Remediation: define a timezone policy and persist a stable local-day key (or original timezone/calendar components), then migrate/query by that key.
- Acceptance: date-line and DST tests preserve the documented invariant under timezone changes.
- Existing issue: new. Estimated grade impact: +2 to +4.

### CLEAN-006 — Notification serialization is not concurrency-isolated

- Priority: P2. Confidence: High. Category: Reliability / concurrency. Effort: M.
- Location: `Faithfully/Services/NotificationService.swift:36`, `Faithfully/Services/NotificationService.swift:130`, `Faithfully/App/ContentView.swift:37`.
- Exact evidence: mutable `operationQueue` is read and overwritten in `enqueue` without an actor or lock. Strict-concurrency build warns that sending `services`, notification results, and the task closure risks data races and becomes an error in Swift 6 mode.
- Reproduction: run the recorded strict build; concurrently invoke schedule/cancel from permission completion and scene/settings refresh paths. Two callers can capture the same predecessor and overwrite the chain tail.
- Impact: the ordering guarantee claimed in the comment is not mechanically enforced; cancelled reminders can be resurrected and `waitForPendingOperations` can miss work.
- Root cause: a task chain is being used as a serial executor without isolating mutation of the chain itself.
- Remediation: make UI/service graph `@MainActor` where appropriate and move notification operations into an actor with a Sendable boundary.
- Acceptance: Swift 6/strict-concurrency build is clean and a simultaneous schedule/cancel stress test is deterministic.
- Existing issue: new. Estimated grade impact: +3 to +5.

### CLEAN-007 — Quality checks are not mandatory or reproducible

- Priority: P2. Confidence: High. Category: Operations / governance. Effort: M.
- Location: repository root (no `.github/workflows`), `.swiftlint.yml:1`, `docs/ship/TEST_RUN.md:39`.
- Exact evidence: GitHub returns `{"total_count":0,"workflows":[]}`; local `swiftlint lint --quiet` fails with `command not found`; XcodeGen/SwiftLint versions are not installed from a pinned bootstrap.
- Reproduction: fresh checkout on this audit host; tests require manual commands and lint cannot run.
- Impact: regressions can merge, and another engineer cannot reproduce the claimed quality gate from repository instructions alone.
- Root cause: verification is documented as a past local event rather than encoded as repository policy.
- Remediation: add pinned bootstrap and mandatory macOS CI for generation-diff, validator, lint, release build, unit tests, UI smoke tests, coverage threshold, and archive validation.
- Acceptance: required checks run on every PR and `main`; a fresh documented environment executes all checks.
- Existing issue: new. Estimated grade impact: +4 to +6 and removes the B cap.

### CLEAN-008 — Several UI tests can pass without testing their named behavior

- Priority: P2. Confidence: High. Category: Testing. Effort: M.
- Location: `FaithfullyUITests/HomeScreenUITests.swift:26`, `FaithfullyUITests/CalendarUITests.swift:42`, `FaithfullyUITests/JourneyUITests.swift:23`, `FaithfullyUITests/SettingsUITests.swift:17`.
- Exact evidence: `completed.exists || true` is unconditional; “colored indicator” checks only day existence; earned-color, journal-display, search-filter, translation-options, and changing-translation tests check only that a generic section renders.
- Reproduction: remove the relevant color, filter, picker options, or selection mutation; the named tests still pass.
- Impact: 23/23 green overstates end-to-end protection and can conceal product regressions.
- Root cause: tests were written as presence smoke checks but named as behavioral assertions and lack deterministic seeded state.
- Remediation: add launch fixtures/state reset and assert actual values, mutations, colors/accessibility values, persistence, filters, and navigation outcomes.
- Acceptance: each named behavior has an assertion that fails when that behavior is intentionally broken; remove all soft/unconditional passes.
- Existing issue: new. Estimated grade impact: +2 to +4.

### CLEAN-009 — Journey silently drops completions after 2030

- Priority: P2. Confidence: High. Category: Correctness / rot. Effort: S.
- Location: `Faithfully/ViewModels/JourneyViewModel.swift:74`.
- Exact evidence: `farFuture = Date.from(year: 2030, month: 12, day: 31)` bounds every Journey total, journal, and search fetch.
- Reproduction: insert a 2031 completion and refresh Journey; `totalCompleted` and journal omit it while BadgeService's unbounded fetch still counts it.
- Impact: a long-lived app presents internally inconsistent totals and loses journal discoverability after an arbitrary date.
- Root cause: an open-ended query was approximated by a temporary hard-coded range.
- Remediation: add an unbounded/all-completions repository query or use a predicate with no upper bound.
- Acceptance: tests cover dates beyond 2030 and distant historical data without sentinel dates.
- Existing issue: new. Estimated grade impact: +1 to +2.

### CLEAN-010 — The archive targets iPad without valid iPad orientation configuration

- Priority: P2. Confidence: High. Category: Configuration / deployment. Effort: S.
- Location: `project.yml:11`, `project.yml:28`.
- Exact evidence: the archive contains `UIDeviceFamily = [1,2]` but only `UISupportedInterfaceOrientations~iphone = [Portrait]`; archive warning: “All interface orientations must be supported unless the app requires full screen.”
- Reproduction: run the recorded generic iOS archive and inspect `Info.plist`.
- Impact: the PRD says iPhone, but the binary declares iPad support and may fail submission validation or deliver an untested iPad experience.
- Root cause: device family was left at Xcode's universal default while only iPhone behavior was configured.
- Remediation: set `TARGETED_DEVICE_FAMILY: "1"` for iPhone-only v1, or fully support/test iPad orientations.
- Acceptance: archive has the intended device family, no orientation warning, and App Store validation passes.
- Existing issue: new. Estimated grade impact: +1 to +3.

### CLEAN-011 — Current documentation contradicts shipped behavior and other launch documents

- Priority: P2. Confidence: High. Category: Documentation / governance. Effort: M.
- Location: `sparc/architecture/system-design.md:42`, `sparc/architecture/system-design.md:79`, `sparc/completion/checklist.md:7`, `docs/ship/TESTFLIGHT_RUNBOOK.md:33`, `docs/ship/README.md:3`.
- Exact evidence: architecture still depicts CloudKit and ESV/NIV/NKJV; the completion checklist retains superseded licensing/screenshot/icon blockers; the runbook says screenshots/icon remain blockers after ship README marks them ready; the listing promises shared scheduling that code does not preserve.
- Reproduction: compare the cited documents with `project.yml`, `BibleTranslation.swift`, shipped assets, and scheduler code.
- Impact: a new owner cannot tell what is current, what blocks release, or which product behavior is authoritative.
- Root cause: sprint documents were appended but not retired or generated from one current source of truth.
- Remediation: mark historical SPARC docs as such, update architecture, consolidate launch status, and add claim-to-test review for App Store copy.
- Acceptance: one current checklist has no contradictions; architecture matches code; every user-facing claim maps to a passing behavior test.
- Existing issue: new. Estimated grade impact: +2 to +4.

### CLEAN-012 — Dead declarations and duplicated profile bootstrap add avoidable ambiguity

- Priority: P3. Confidence: High. Category: Dead code / duplication. Effort: S.
- Location: `Faithfully/Models/Results/CompletionResult.swift:3`, `Faithfully/Utilities/Constants.swift:4`, `Faithfully/App/AppEnvironment.swift:80`, `Faithfully/ViewModels/SettingsViewModel.swift:27`.
- Exact evidence: `CompletionResult`, `totalChallenges`, `gracePeriodDays`, `defaultMorningHour`, and `defaultEveningHour` have declaration-only references; both environment and settings fetch-or-create `UserProfile`.
- Reproduction: repository-wide symbol search returns one occurrence for each dead declaration; compare both bootstrap blocks.
- Impact: stale design artifacts obscure the real completion API and permit two profile owners, especially when a fetch error is converted to an empty result.
- Root cause: architecture changed without deleting scaffolding or making the composition root the sole owner.
- Remediation: delete dead declarations and inject the already-bootstrapped profile into SettingsViewModel.
- Acceptance: dead-symbol search is clean and only one component creates/owns the profile.
- Existing issue: new. Estimated grade impact: +1.

Security tracks A–G were all covered: no injection surface, secrets, auth surface, remote input/upload, third-party dependency, permissive server configuration, sensitive logging, or broad serialization was found. Code-health tracks H–K produced CLEAN-008, CLEAN-011, and CLEAN-012; no additional reachable dead route or harmful abstraction was verified.

## 7. Fixed since previous review

This is the first recorded senior-grade review, so there is no previous score or finding set to verify. No product code was changed and no remediation commits were created in grade mode. `AUDIT.md` is the only intended worktree change.

## 8. Path to A

1. **Production and product blockers** — CLEAN-001, CLEAN-002, CLEAN-003, CLEAN-010. Expected +8 to +13. Verify with two-user schedule tests, enrollment-boundary tests, journal boundary/failed-save UI tests, generic archive, and App Store validation. Exit: truthful listing, no pre-start credit, no silent journal loss, clean archive.
2. **Correctness and lifecycle invariants** — CLEAN-004, CLEAN-005, CLEAN-006, CLEAN-009. Expected +8 to +12. Verify interruption/relaunch, injected persistence failures, timezone/DST matrix, simultaneous notification operations, strict Swift 6 build, and post-2030 tests. Exit: atomic/reconcilable state, explicit actor/date ownership, recoverable failures.
3. **Test and CI enforcement** — CLEAN-007, CLEAN-008. Expected +5 to +8 and removes the B cap. Verify fresh bootstrap plus required PR checks running validator, lint, build, unit, UI, coverage, analyzer, and archive. Exit: named UI behaviors fail under deliberate mutation; `main` cannot bypass checks.
4. **Operations and data governance** — signed TestFlight/App Store validation, crash/support ownership, file-protection and recovery policy, device accessibility/performance passes. Expected +4 to +7 and removes the B+ operations cap. Exit: a new operator can ship, observe, diagnose, and recover without the author.
5. **Maintainability and governance** — CLEAN-011, CLEAN-012 plus Swift 6 migration. Expected +3 to +5. Verify no strict-concurrency warnings, no dead declarations, one current architecture/checklist, and claim-to-test traceability. Exit: unfamiliar engineers have one accurate source of truth.

Recommended recurring commands after remediation:

```text
xcodegen generate && git diff --exit-code -- Faithfully.xcodeproj/project.pbxproj
python3 scripts/validate_challenges.py
swiftlint lint --strict
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully -destination '<pinned simulator>' -enableCodeCoverage YES test
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully -configuration Release -destination 'generic/platform=iOS' archive
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully SWIFT_STRICT_CONCURRENCY=complete build
```

## 9. Senior-engineer assessment

- Could a new senior own the system safely? **Not yet.** The code is learnable, but contradictory product rules and implicit persistence/concurrency ownership require author knowledge.
- Are deployments repeatable? **Partly.** Local archive is repeatable; signing, lint bootstrap, CI, and upload validation are not.
- Are trust boundaries enforced at runtime? **Mostly for the surfaces present.** There is no remote/auth surface and bundled content fails closed, but user journal/persistence result boundaries are not honest.
- Is concurrency designed or accidental? **Intentional but not mechanically isolated.** The task-chain design has a clear goal; strict diagnostics show its actor contract is incomplete.
- Are AI changes evaluable before shipping? **Static content only, partly.** Schema/copy validation is repeatable; scripture spot checks are documented, but CI does not enforce either and there is no runtime AI.
- Can operators detect, diagnose, and recover? **No.** Crash diagnostics depend on future App Store tooling, persistence errors are hidden/crashing, and no recovery path exists.
- Is documentation accurate? **No.** Privacy/licensing are strong, but architecture, checklist, runbook, and product listing disagree.
- What prevents an A? The three release blockers, non-atomic/hidden persistence failures, timezone and actor ambiguity, vacuous tests without CI, manual operations, and documentation rot.

Reliability failure timelines:

1. **Two notification mutations overlap.** Both callers read the same `operationQueue`; each creates a child and one overwrites the tail. The intended total order is not guaranteed. Invariant: **not preserved**.
2. **Process exits after completion save, before badge save.** Completion remains; the exact earned badge may remain absent until a future completion happens to re-evaluate it. Invariant: **not preserved**.
3. **User crosses the date line after completing.** The stored start-of-day instant is reinterpreted under a new `Calendar.current`; query/streak grouping can shift. Invariant: **not demonstrably preserved**.

```json
{
  "audit_date": "2026-08-02",
  "commit": "9ffe014f3140ac1bd73014ce36dd94df5c26f44d",
  "overall_score": 77,
  "overall_grade": "C+",
  "production_ready": false,
  "senior_quality": false,
  "applied_grade_caps": [
    "unbounded_or_race_prone_async_processing:B",
    "no_mandatory_ci:B",
    "no_production_observability_story:B+"
  ],
  "category_scores": {
    "product_coherence": 70,
    "architecture": 78,
    "correctness": 76,
    "security_privacy": 90,
    "reliability_concurrency": 68,
    "testing_ai_quality": 84,
    "maintainability": 83,
    "operations_observability": 62,
    "documentation_governance": 66
  },
  "release_blockers": ["CLEAN-001", "CLEAN-002", "CLEAN-003"],
  "p0_count": 0,
  "p1_count": 3,
  "p2_count": 8,
  "p3_count": 1,
  "fixed_since_previous_review": [],
  "remaining_existing_issues": [],
  "new_findings": [
    "CLEAN-001", "CLEAN-002", "CLEAN-003", "CLEAN-004",
    "CLEAN-005", "CLEAN-006", "CLEAN-007", "CLEAN-008",
    "CLEAN-009", "CLEAN-010", "CLEAN-011", "CLEAN-012"
  ],
  "top_three_next_actions": [
    "Replace tenure-relative challenge rotation with one truthful shared-date contract",
    "Enforce user start date as the earliest visible and completable day",
    "Prevent silent journal truncation and preserve drafts on persistence failure"
  ]
}
```
