# Green Test Run Evidence — Sprint E

> **SNAPSHOT — a single past local run.** Test counts here are stale by design. The live numbers come from `make ci`; see [`MERGE_CHECKLIST.md`](MERGE_CHECKLIST.md).


Executed locally on the owner's development machine, **2026-07-20**, branch `sprint-e-ship-prep` (from `main` @ f6e1c78).

## Toolchain

```
$ xcodebuild -version
Xcode 26.6
Build version 17F113
```

Destination: `platform=iOS Simulator,name=iPhone 17` (iOS 26 simulator). Project generated with XcodeGen from `project.yml` immediately before testing.

## Unit tests — PASS

```
$ xcodegen generate
$ xcodebuild -scheme Faithfully -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:FaithfullyTests test

Test Suite 'All tests' passed at 2026-07-20 14:08:42.857.
	 Executed 176 tests, with 0 failures (0 unexpected) in 0.737 (0.811) seconds
** TEST SUCCEEDED **
```

**176 tests, 0 failures**, across 18 suites (services, view models, badge evaluation, streaks/grace period, scheduler, loader fail-closed behavior, notification wiring, integration). The baseline run earlier the same day was 172/172; the final run includes 4 new `AppInfoTests` added in this sprint alongside the Settings → About change (version now read from the bundle plus a static privacy blurb).

Flake note: the first attempt on a cold simulator failed to install the test runner ("Application failed preflight checks" from SBMainWorkspace). Pre-booting the simulator (`xcrun simctl boot` + `bootstatus -b`) and re-running fixed it. This is a simulator lifecycle flake, not a test failure — worth remembering if CI is added later.

## App build — PASS

```
$ xcodebuild -scheme Faithfully -destination 'platform=iOS Simulator,name=iPhone 17' build
** BUILD SUCCEEDED **
```

Zero compiler warnings. The only log line flagged was `appintentsmetadataprocessor … Metadata extraction skipped. No AppIntents.framework dependency found.` — informational, the app doesn't use App Intents.

## SwiftLint — PASS (light-touch)

SwiftLint 0.65.0 (Homebrew). A minimal `.swiftlint.yml` was added in this sprint: it disables purely stylistic rules that generated ~100 rename/reflow diffs (`identifier_name`, `line_length`, `trailing_comma`, `multiple_closures_with_trailing_closure`) and keeps everything else at defaults.

```
$ swiftlint lint --quiet
Faithfully/Views/Onboarding/OnboardingView.swift:7 warning implicit_optional_initialization
FaithfullyTests/CalendarViewModelTests.swift:20 warning force_try (test fixture setup)
exit: 0
```

**0 errors, 2 warnings**, both benign. Mass auto-fix was deliberately not run during ship prep.

## Not run in this pass

- **UI tests** (`FaithfullyUITests`) — out of scope for this evidence run; unit + integration suites cover the logic.
- **CI** — no GitHub Actions workflow yet; this is a documented local green run per issue #13 acceptance. If CI is added, use a macOS 15+ runner, pre-boot the simulator, and expect the flake noted above.
