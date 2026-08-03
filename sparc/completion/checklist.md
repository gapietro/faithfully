# SPARC Phase 5: Completion
## Faithfully iOS App — Launch Readiness Checklist

> **HISTORICAL — superseded 2026-08-02.**
>
> This checklist recorded a point-in-time pass on 2026-07-20 and has been
> overtaken twice: by Sprint F (screenshots and icon, both now done) and by the
> post-audit remediation (tracker #39), which added an executable gate.
>
> It is kept for the record. Do not read it as current status, and do not tick
> boxes in it.
>
> Current sources of truth:
>
> | Question | Where |
> |---|---|
> | What passes right now | `make ci` — see [`docs/ship/MERGE_CHECKLIST.md`](../../docs/ship/MERGE_CHECKLIST.md) |
> | Is it ready to ship | [`docs/ship/README.md`](../../docs/ship/README.md) |
> | How is it built | [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) |
> | Which promises are proven | [`docs/ship/CLAIMS.md`](../../docs/ship/CLAIMS.md) |
>
> The two blockers this document names as top priority — scripture accuracy and
> translation licensing — were both cleared for v1 under the public-domain
> strategy (WEB + KJV). It was never updated to say so.

### 1. Code Quality
- [ ] All tests pass (unit, integration, UI) — *unit + integration: 176/176 green 2026-07-20 (TEST_RUN.md); UI test target not executed*
- [ ] Test coverage > 90% on Services and ViewModels — *not measured*
- [ ] SwiftLint: zero warnings — *0 errors, 2 benign warnings under new light-touch `.swiftlint.yml`*
- [x] No force-unwraps in production code — *grep-verified 2026-07-20: no `!` unwraps, `try!`, or `as!` in `Faithfully/`*
- [x] No TODO/FIXME comments remaining — *grep-verified 2026-07-20*
- [x] All deprecated API usage resolved — *zero compiler warnings in 2026-07-20 build*
- [ ] Memory leaks checked via Instruments (Leaks template)
- [ ] No retain cycles in closures — *not audited*

### 2. Performance
- [ ] App launch to home screen: < 2 seconds (iPhone 12+) — *not measured on device*
- [ ] Challenge JSON loads in < 100ms — *not explicitly measured (loader test suite runs in ~0.2s total, so likely, but unmeasured)*
- [ ] Calendar renders in < 200ms
- [ ] Badge evaluation completes in < 50ms
- [ ] No janky scrolling (60fps verified in Instruments)
- [ ] SwiftData queries optimized (no N+1 fetches)
- [ ] App size < 50MB (including all badge assets)

### 3. Content Verification
- [x] All 365 challenges present in challenges.json — *unit test `testLoads365ChallengesFromBundledJSON` + independent script check 2026-07-20*
- [x] Zero null or empty fields in any challenge — *unit test `testAllChallengesHaveNonEmptyRequiredFields` + script scan of all 365 rows*
- [x] Scripture text spot-checked against published Bible text (20+ random samples per translation) — *done in Sprint D (34 samples); **failures found**, see SCRIPTURE_SPOT_CHECK.md*
- [ ] ESV text verified accurate — *FAILED: ~110 of 365 ESV fields contain NIV text; must be re-sourced*
- [ ] NIV text verified accurate — *FAILED: retired NIV 1984 wording in sampled rows*
- [ ] NKJV text verified accurate — *91% sample pass rate; 3 sampled failures outstanding*
- [x] No consecutive same-category days in default schedule — *unit test `testNoTwoConsecutiveDaysHaveSameCategory`; known exception: leap-year Dec 30/31 duplicate (SCHEDULER_DISTRIBUTION.md)*
- [x] Giving challenges correctly pinned to first Saturdays — *unit tests + full-year simulation (12/12 first Saturdays, 11/11 giving challenges used)*
- [ ] All challenge descriptions are actionable (verb-first) — *editorial pass done Sprint D but not systematically re-verified*
- [x] No AI writing patterns (em-dashes, hedge words, filler phrases) — *Sprint D editorial pass; 0 em-dashes outside scripture text confirmed by scan 2026-07-20*

### 4. Badge Assets
- [ ] All journey badges designed (5): 5K, 10K, Half Marathon, Marathon, Ultra — *placeholder art only; Recraft pack not commissioned*
- [ ] All streak badges designed (5): Ember, Flame, Fire, Furnace, Unquenchable
- [ ] All category badges designed (40): 10 categories x 4 levels
- [ ] Grayscale silhouette versions for unearned badges
- [ ] All badges at 3x resolution for Retina displays
- [x] Badge celebration animation implemented and tested — *BadgeCelebrationView with reduce-motion path; celebration logic covered by unit tests; visual QA pending real art*
- [ ] 10 category icons designed (line art style)

### 5. Accessibility
- [ ] VoiceOver: all screens navigable, all interactive elements labeled — *accessibility identifiers present on key controls; full VoiceOver audit not done*
- [ ] Dynamic Type: all text scales with system font size — *not audited*
- [ ] Color contrast: meets WCAG 2.1 AA minimum (4.5:1 for text)
- [ ] No information conveyed by color alone (badges use shape + text too)
- [x] Reduce Motion: celebration animations respect this setting — *`accessibilityReduceMotion` guard in BadgeCelebrationView*

### 6. Dark Mode
- [ ] All screens render correctly in light mode — *no systematic visual audit yet*
- [ ] All screens render correctly in dark mode
- [x] System setting toggle works — *`.system` preference wired via `preferredColorScheme` at app root; unit-tested in SettingsViewModelTests*
- [x] Manual override in Settings works — *Settings picker (System/Light/Dark), unit-tested*
- [ ] Badge art looks good on both backgrounds — *pending real badge art*
- [x] No hard-coded colors (all via Asset Catalog or semantic colors) — *grep-verified: no RGB literals; Navy/Gold/Cream/Forest/Accent colorsets in Asset Catalog*

### 7. Edge Cases Tested
- [ ] First launch (no data, onboarding flow) — *onboarding wiring unit-tested; full first-launch flow not manually QA'd*
- [x] Day 1 completion — *`testFullCompletionFlow_ViewCompleteVerifyPersistenceStreakBadge`*
- [x] Day 365 completion (year boundary) — *`testDay365Completion_Day366ShowsDifferentChallengeThanDay1`*
- [x] Day 366 (year rotation) — *same test + `testYear1AndYear2ReturnDifferentChallengesForSameCalendarDate`*
- [x] Leap year handling (Feb 29) — *`testAddingDaysHandlesLeapDay` + full leap-year scheduler simulation (SCHEDULER_DISTRIBUTION.md)*
- [ ] Midnight timezone edge case (challenge changeover) — *day-rollover refresh implemented (Sprint A) but timezone-specific cases untested*
- [ ] User changes timezone mid-streak
- [ ] Device date changed manually (anti-cheat)
- [ ] App launched after 30 days of inactivity
- [x] 1000+ completions (performance) — *`test1000CompletionsDoesNotDegradePerformance`*
- [ ] Journal entry at max length (2000 chars)
- [x] No internet connection (full offline operation) — *no networking code exists in the app (grep-verified); all data bundled/local*
- [ ] Low storage warning
- [ ] Background app refresh

### 8. Notifications
*Checked items below are verified at the unit level (scheduling and policy logic, 25 tests across NotificationServiceTests/NotificationWiringTests); on-device delivery has not been manually verified.*
- [x] Morning notification fires at configured time — *`testScheduleAllNotificationsCreatesMorningNotification`, `testScheduledTriggersUseProfileTimes`*
- [x] Evening reminder fires only if challenge not completed — *creation + `testCompletingTodayCancelsEveningReminderAndStreakWarning`*
- [x] Streak warning fires only if streak >= 7 and not completed — *`testScheduleStreakWarningCreatesNotificationOnlyIfStreakGTE7`, `testStreakWarningNotArmedWhenTodayAlreadyCompleted`*
- [x] Badge celebration notification fires on badge earned — *`testBadgeAwardSchedulesCelebrationOnlyWhenEnabled`*
- [x] All notifications respect user's enabled/disabled settings — *`testNotificationsRespectUserDisabledPreferences` + per-toggle tests*
- [ ] Tapping notification opens app to correct screen — *not implemented/verified*
- [ ] Notifications work when app is in background — *not device-tested*
- [ ] Notifications work when app is terminated — *not device-tested*

### 9. CloudKit — **DEFERRED to v1.x** (not a v1 launch blocker)
*Decision 2026-07-20: v1 ships local SwiftData only; no iCloud entitlement or container exists. See [docs/ship/CLOUDKIT_DECISION.md](../../docs/ship/CLOUDKIT_DECISION.md). The items below move to the v1.x milestone and are intentionally not part of v1 launch readiness.*
- [ ] (v1.x) Initial sync on first launch with iCloud enabled
- [ ] (v1.x) Completion syncs to cloud within 30 seconds on Wi-Fi
- [ ] (v1.x) Badge sync works
- [ ] (v1.x) Conflict resolution: last-writer-wins
- [ ] (v1.x) Graceful handling when iCloud is disabled
- [ ] (v1.x) Graceful handling when iCloud storage is full
- [ ] (v1.x) Restore from cloud on fresh install (same Apple ID)

### 10. App Store Preparation
*Copy drafts live in [docs/ship/APP_STORE_LISTING.md](../../docs/ship/APP_STORE_LISTING.md); nothing has been entered into App Store Connect.*
- [ ] App name: "Faithfully" (verify availability)
- [ ] Bundle ID registered in Apple Developer Portal — *`com.faithfully.app` set in project.yml; not registered*
- [ ] App category: Lifestyle — *decided in draft; not set in ASC*
- [ ] Age rating: 4+ (no objectionable content) — *decided in draft; not set in ASC*
- [ ] Privacy policy URL created and hosted — *text drafted (docs/ship/PRIVACY_POLICY.md); needs hosting*
- [x] App description written (4000 char max) — *draft in APP_STORE_LISTING.md; pending the owner review*
- [ ] Keywords researched and selected (100 char max) — *draft exists; no ASO research done*
- [x] What's New text written — *draft in APP_STORE_LISTING.md*
- [ ] 6.7" screenshots (iPhone 15 Pro Max): 5-8 screenshots — *plan + sizes documented (SCREENSHOTS_AND_ICON.md); none captured*
- [ ] 6.1" screenshots (iPhone 15 Pro): 5-8 screenshots
- [ ] App preview video (optional but recommended)
- [ ] App icon: 1024x1024 final version — *current icon is placeholder navy/cross*
- [x] Promotional text (170 char max) — *draft in APP_STORE_LISTING.md*
- [ ] Support URL — *placeholder only*
- [ ] Copyright notice — *drafted; confirm exact entity*

### 11. TestFlight Beta
*Runbook for the owner: [docs/ship/TESTFLIGHT_RUNBOOK.md](../../docs/ship/TESTFLIGHT_RUNBOOK.md). No build has been uploaded.*
- [ ] Internal testing: 3+ team members for 1 week
- [ ] External testing: 10+ beta users for 2 weeks — *BLOCKED on scripture accuracy + licensing (see runbook)*
- [ ] All crash reports reviewed and fixed
- [ ] Beta feedback incorporated
- [ ] Final regression test after all fixes

### 12. Pre-Submission Final Check
- [ ] Archive build succeeds — *simulator build succeeds; device archive not attempted (needs signing team)*
- [x] No warnings in Xcode build — *zero compiler warnings, 2026-07-20 simulator build*
- [ ] App Thinning verified (asset variants)
- [ ] Export compliance: No encryption (or proper declaration) — *answer known (standard/exempt); not declared in ASC*
- [ ] Content rights: all scripture text used with permission/public domain — ***BLOCKED: see TRANSLATION_LICENSING.md — not cleared to ship as-is***
- [x] IDFA: not used (no tracking) — *no tracking or analytics code; pure native*
- [x] Third-party SDK compliance: none (pure native) — *zero external dependencies in project.yml*
- [ ] Privacy nutrition label completed in App Store Connect — *answers drafted ("Data Not Collected"); ASC not touched*
- [ ] Review notes for Apple: explain app purpose, any demo credentials needed — *draft in APP_STORE_LISTING.md; not entered*

### 13. Post-Launch Monitoring
- [ ] Crash reporting enabled (native Xcode Organizer)
- [ ] App Store rating prompt configured (after 30 completed challenges) — *not implemented*
- [ ] Support email configured and monitored
- [ ] v1.1 roadmap documented (top user-requested features) — *CloudKit deferral is the first v1.x item (CLOUDKIT_DECISION.md)*

---

## Launch Command

When all boxes above are checked (CloudKit §9 excepted — deferred to v1.x):
```
1. Archive in Xcode (Product → Archive)
2. Upload to App Store Connect
3. Submit for Review
4. Expected review time: 24-48 hours
5. Release: Manual (so you can coordinate announcement)
```

**the owner performs these steps.** Per standing rule, Scout/agents do not upload or submit builds.
