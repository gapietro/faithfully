# Screenshots & App Icon Plan

## Required screenshot sizes (App Store Connect, iPhone-only app)

App Store Connect currently requires only the largest iPhone size and scales it down for smaller devices unless you upload device-specific sets:

| Display | Portrait pixels | Capture device | Status |
|---|---|---|---|
| **6.9" (required)** | 1320 × 2868 | iPhone 17 Pro Max simulator | ✅ captured 2026-07-30 |
| 6.5"/6.7" (optional override) | 1290 × 2796 or 1284 × 2778 | iPhone 17 / 15 Pro Max simulator | optional |

No iPad set needed (iPhone-only target, portrait-only). 3–10 screenshots per set; plan for 6 below. Simulator capture: full-device PNG via UITest `XCUIScreen.main.screenshot()` (exact device resolution — ASC accepts them).

## Storyboard — 6 shots (checked in)

Files live under [`screenshots/6.9/`](screenshots/6.9/):

| # | File | Screen | Caption idea |
|---|------|--------|----------------|
| 1 | `01_daily_walk.png` | Daily Walk hero — scripture card + Complete | "One challenge. Every day." |
| 2 | `02_completion.png` | Completion / Reflection sheet + journal | "Walk it out, then write it down." |
| 3 | `03_calendar.png` | Calendar month grid | "Watch your year fill in." |
| 4 | `04_journey.png` | Journey stats + badges | "Milestones on your walk." |
| 5 | `05_onboarding.png` | Welcome / promise | "No account. No ads. Yours alone." *(copy can be refined in ASC)* |
| 6 | `06_settings.png` | Settings / appearance + notifications | Settings polish |

Optional later: dark-mode Daily Walk; giving-challenge variety shot.

## How to re-capture

```bash
cd path/to/faithfully
UDID=$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 17 Pro Max/ {print $2; exit}')
export FAITHFULLY_SCREENSHOT_DIR=/tmp/faithfully-screenshots-6.9
rm -rf "$FAITHFULLY_SCREENSHOT_DIR" && mkdir -p "$FAITHFULLY_SCREENSHOT_DIR"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcodegen generate
xcodebuild test -scheme Faithfully \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:FaithfullyUITests/ScreenshotStoryboardTests/testCaptureStoryboard
cp -f "$FAITHFULLY_SCREENSHOT_DIR"/*.png docs/ship/screenshots/6.9/
```

Driver: `FaithfullyUITests/ScreenshotStoryboardTests.swift`  
Uses launch arg `-hasCompletedOnboarding YES/NO` and accessibility IDs. Unique MD5s required (no duplicate frames).

## App icon

**Installed.** `Faithfully/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is the owner-selected Recraft v3 (open book + gold cross). Candidates under `docs/ship/icons/`.

## Blocking realities (resolved for v1 capture)

- Scripture strategy settled (WEB + KJV PD) — shots show shipping text.
- Icon final before capture.
- Prefer UITest full-screen PNG over flaky host-window grabs.
