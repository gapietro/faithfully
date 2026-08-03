# Faithfully — session handoff

> **SNAPSHOT — 2026-07-22.** Predates Sprint F (icon, screenshots) and the post-audit remediation (#39). Kept for the record; for current status read [`README.md`](README.md).


**Written:** 2026-07-22  
**Repo:** `gapietro/faithfully` (private)  
**Clone:** `path/to/faithfully` on development machine  
**Main HEAD at handoff:** `7ec15c8` — Merge PR #36 (Recraft app icon v3)  
**gh user:** `scoutapietro` (push + pull + triage; no admin)

This file is the durable resume point after the post-audit sprint run (A–E + F1 + privacy + icon).  
Hermes conversation history also retains the full thread; search “Faithfully sprint” / “Recraft icon” if needed.

---

## Executive status

| Area | Status |
|------|--------|
| Code correctness (Sprint A) | ✅ Merged PR #15 |
| MVP wiring (Sprint B) | ✅ Merged PR #16 |
| Design pass 1 (Sprint C) | ✅ Merged PR #17 |
| Content editorial + legal docs (Sprint D) | ✅ Merged PR #18 |
| Ship prep docs (Sprint E) | ✅ Merged PR #19 |
| Scripture strategy + PD bundle (F1) | ✅ Merged PR #34 — **WEB + KJV only**, default WEB |
| Privacy policy URL (F2) | ✅ Merged PR #35 — live gist + Settings link |
| App icon (F2 partial #26) | ✅ Merged PR #36 — Recraft v3 open book + gold cross |
| App Store screenshots (#26 remainder) | 🔴 **Not done** — capture WIP abandoned mid-session |
| Internal TestFlight (#27) | 🟡 the owner’s clicks — runbook ready |
| Pre-public gate (#28) | 🟡 Explicit the owner OK after green lights |
| Epic G beta polish (#21, #29–#33) | ⏳ After first internal TF preferred |

**Traffic light board:** [`docs/ship/README.md`](README.md)

**Bottom line:** Internal TestFlight is unblocked on content/privacy/icon once the owner does signing (#27). **Public** release still needs good screenshots (#26), then #28. Badge art is Epic G #32, not launch-hard-blocked.

---

## Open GitHub issues (work queue)

### Epic F — Launch unblock — [#20](https://github.com/gapietro/faithfully/issues/20)

| # | Title | Owner-ish | Notes |
|---|--------|-----------|--------|
| **#26** | Final app icon + App Store screenshots | Scout / the owner | **Icon done.** Screenshots remaining. |
| **#27** | Internal TestFlight — the owner signing & first build | **the owner** | [`TESTFLIGHT_RUNBOOK.md`](TESTFLIGHT_RUNBOOK.md) |
| **#28** | Pre-public gate | **the owner OK** | Do not coerce agents to Submit |

Closed under F: #22 strategy (option 1 PD), #23 text, #24 attribution, #25 privacy.

### Epic G — Beta polish — [#21](https://github.com/gapietro/faithfully/issues/21)

| # | Title |
|---|--------|
| #29 | VoiceOver + Dynamic Type + contrast |
| #30 | Midnight day rollover without backgrounding |
| #31 | UITest smoke stabilization |
| #32 | Real badge & category artwork (Recraft) |
| #33 | Rating prompt + crash reporting decision |

Audit epic **#1** is closed.

---

## Locked product decisions

1. **Scripture v1 = public domain only** (the owner, #22)  
   - Translations in app: **WEB** (default) + **KJV**  
   - ESV/NIV/NKJV **removed** from bundle (das commercial path deferred)  
   - Keys: `scripture_text_web`, `scripture_text_kjv`  
   - Docs: [`../content/TRANSLATION_LICENSING.md`](../content/TRANSLATION_LICENSING.md), [`../content/SCRIPTURE_SPOT_CHECK_PD.md`](../content/SCRIPTURE_SPOT_CHECK_PD.md)  
   - Scripts: `scripts/fetch_pd_scripture.py`, `scripts/validate_challenges.py`

2. **CloudKit deferred** to post-v1 — [`CLOUDKIT_DECISION.md`](CLOUDKIT_DECISION.md)

3. **Agents must not** create ASC records, upload TF builds, or Submit for Review without explicit the owner OK on private channel.

4. **Recraft** is approved for brand art (icon done; badges = #32). Key is **not in git**.

---

## Secrets & tooling (development machine)

| Item | Where |
|------|--------|
| Recraft API key | macOS Keychain service **`recraft.ai`**, account `REDACTED` — API validated HTTP 200 against `external.api.recraft.ai` |
| GitHub | `gh` as `scoutapietro` (keyring) |
| Claude Code | Max account; model used: `claude-fable-5` (`claude` CLI) |
| Xcode | 26.x at `/Applications/Xcode.app`, `xcode-select` → full Xcode |
| XcodeGen / SwiftLint / xcbeautify | Homebrew installed |
| Simulators | iPhone 17 family, including **iPhone 17 Pro Max** (6.9″ / 1320×2868 targets) |

**Do not commit** keys. Prefer Keychain or gitignored env.

---

## Privacy policy (live)

- **Canonical (paste into App Store Connect):**  
  https://gist.github.com/scoutapietro/96c48a68f12efe3950b5bc359db70974  
- Raw HTML:  
  https://gist.githubusercontent.com/scoutapietro/96c48a68f12efe3950b5bc359db70974/raw/index.html  
- In-repo source: `docs/privacy/index.html`  
- App: `AppInfo.privacyPolicyURL` + Settings → **Privacy Policy** link  
- Longer-term: first-party domain / GitHub Pages (private repo Pages needed admin; gist used instead)

---

## App icon

- **Selected:** Recraft variant **v3** — open book + slender gold cross on navy  
- Installed: `Faithfully/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024 PNG)  
- Candidates + notes: `docs/ship/icons/` (v1–v4 + `README.md`)

---

## #26 screenshots — incomplete work dump

**Intent:** Capture 详情 6+ full-bleed portrait PNGs at **1320×2868** (iPhone 17 Pro Max) per [`SCREENSHOTS_AND_ICON.md`](SCREENSHOTS_AND_ICON.md).

| # | Shot | Status |
|---|------|--------|
| 1 | Daily Walk hero | not reliably captured |
| 2 | Completion sheet | not reliably captured |
| 3 | Calendar | not reliably captured |
| 4 | Journey / badges | not reliably captured |
| 5 | Onboarding | partial / flaky via UITest |
| 6 | Settings | not reliably captured |

### What was tried
1. Branch `sprint-f2-screenshots` (local; **not merged**).  
2. `FaithfullyUITests/ScreenshotStoryboardTests.swift` — storyboard driver writing under `/tmp/faithfully-screenshots-6.9`.  
3. Device UDID used: `B662D859-FCD2-42B0-859C-576662F54F01` (iPhone 17 Pro Max).  
4. **Problem:** Many PNG outputs were **duplicate hashes** after onboarding — UITest often failed to advance past notification permission / tab bar, or screenshots did not reflect real distinct screens.  
5. Manual `xcrun simctl launch` + `simctl io … screenshot` **did** produce a good full-res frame of real onboarding (`debug_launch` class capture once worked better than the UITest batch).

### Recommended resume path for screenshots
Prefer **manual/scripted simctl** over flaky UITest matrix:

```bash
cd path/to/faithfully
UDID=<iPhone 17 Pro Max UDID>
xcodegen generate
xcodebuild -scheme Faithfully -destination "platform=iOS Simulator,id=$UDID" build
xcrun simctl boot "$UDID" || true
xcrun simctl uninstall "$UDID" com.faithfully.app || true
xcrun simctl install "$UDID" ~/Library/Developer/Xcode/DerivedData/Faithfully-*/Build/Products/Debug-iphonesimulator/Faithfully.app
xcrun simctl launch "$UDID" com.faithfully.app
# Dismiss notification alert if needed, navigate UI, then:
xcrun simctl io "$UDID" screenshot docs/ship/screenshots/6.9/01_daily_walk.png
# …repeat for storyboard shots
```

Optional: finish UITest driver so `app.screenshot()` is used (not host screen), SpringBoard alert dismissal is solid, then collect only **unique MD5** PNGs into `docs/ship/screenshots/6.9/`.

Store under: `docs/ship/screenshots/6.9/` with flat names matching the storyboard.  
Then flip Marketing screenshots row in `README.md` to green and close #26.

Clean WIP was **not** left dirty on `main` at handoff writing time (bad/local screenshot artifacts stripped). Re-create UITest harness when continuing #26.

---

## Notable ship docs map

| Path | Purpose |
|------|---------|
| `docs/ship/README.md` | Traffic light summary |
| `docs/ship/TESTFLIGHT_RUNBOOK.md` | the owner TF steps; blockers list |
| `docs/ship/APP_STORE_LISTING.md` | Copy + privacy URL |
| `docs/ship/PRIVACY_POLICY.md` | Policy which mirrors hosted HTML |
| `docs/ship/SCREENSHOTS_AND_ICON.md` | Shot list + sizes |
| `docs/ship/CLOUDKIT_DECISION.md` | Deferral |
| `docs/ship/TEST_RUN.md` | Historical green `xcodebuild test` evidence |
| `docs/content/*` | Spot-checks, licensing, scheduler notes |
| `sparc/completion/checklist.md` | Honest launch checklist |

---

## Stack reminders

- iOS 17+, SwiftUI, SwiftData, XcodeGen `project.yml`, bundle `com.faithfully.app`  
- Composition root: `AppEnvironment` / `AppServices`  
- Completions keyed by **scheduled calendar day**, not challengeId  
- `refreshForCurrentDate()` on scene Phase active; midnight-without-background still #30  
- Unit suite last known healthy (~177+ tests on F1/privacy runs); re-run after screenshot harness lands  

```bash
xcodegen generate
xcodebuild -scheme Faithfully -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FaithfullyTests test
python3 scripts/validate_challenges.py
```

---

## Suggested next session order

1. **Finish #26 screenshots** (simctl manual or fixed UITest) → PR → close #26  
2. **the owner #27** internal TestFlight using runbook  
3. Optional parallel: **#32** Recraft badge pack (same Keychain key)  
4. **#28** only after the owner explicit OK  

---

## Contact / trust

- Repository owner — private channel primary command channel  
- Support email used in privacy: `gapietro@gmail.com`  

Do not take store-shipping actions without the owner on private channel.
