# Screenshots & App Icon Plan

## Required screenshot sizes (App Store Connect, iPhone-only app)

App Store Connect currently requires only the largest iPhone size and scales it down for smaller devices unless you upload device-specific sets:

| Display | Portrait pixels | Capture device | Status |
|---|---|---|---|
| **6.9" (required)** | 1320 × 2868 | iPhone 17 Pro Max / 16 Pro Max simulator | ⛔ not captured |
| 6.5"/6.7" (optional override) | 1290 × 2796 or 1284 × 2778 | iPhone 17 / 15 Pro Max simulator | optional |

No iPad set needed (iPhone-only target, portrait-only). 3–10 screenshots per set; plan for 6 below. Simulator capture: run the app, then `xcrun simctl io booted screenshot shot.png` (simulator captures are exact device-resolution PNGs — ASC accepts them).

## Storyboard — 6 shots

Order matters: the first 2–3 are what shows in search results.

1. **Daily Walk (hero)** — today's challenge card with scripture, category, and Complete button. Caption idea: "One challenge. Every day."
2. **Completion moment** — completion sheet / celebration with journal field. "Walk it out, then write it down."
3. **Calendar** — month view with completed days filled and today highlighted. "Watch your year fill in."
4. **Journey / badges** — streak + earned badges grid. "Milestones on your walk."
5. **Onboarding / promise screen** — the no-account, offline pitch. "No account. No ads. Yours alone."
6. **Settings / appearance** — notification times + dark mode (could swap for a dark-mode Daily Walk shot instead, which markets better).

Optional 7–8: a dark-mode variant of shot 1; a giving-challenge example to show challenge variety.

Style pass (later, with real icon art): consistent device frame or flat full-bleed, caption text top, one accent color from the app palette (navy/gold/cream).

## Blocking realities

- **Screenshots should wait for the real app icon and any content fix** — shots showing "ESV" text that is actually NIV (see `docs/content/SCRIPTURE_SPOT_CHECK.md`) shouldn't be marketing material. Capture after the content/licensing resolution.
- **App icon is a placeholder.** `Faithfully/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` is the Sprint C placeholder (navy background, simple cross). Replace with final 1024×1024 art (single-size icon; Xcode generates variants) **before** store submission — and before screenshots, since the icon appears in nothing but still sets the listing's visual identity alongside them. Real badge art (Recraft pack) is likewise outstanding; the Journey screenshot will look better after it lands.

No screenshot PNGs were captured in Sprint E — documenting was the deliverable; capture is quick once content/icon are final.
