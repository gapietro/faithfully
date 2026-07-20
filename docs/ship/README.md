# Ship Readiness — Sprint E summary (2026-07-20)

One-page status for Greg. Detail lives in the linked docs.

| Area | Status | Notes |
|---|---|---|
| Code & tests | 🟢 Ready | 176/176 unit tests green, build clean, lint clean — [TEST_RUN.md](TEST_RUN.md) |
| Design pass 1 | 🟢 Ready | Sprint C brand assets, motion, badge names in place |
| Content editorial | 🟢 Ready | Sprint D editorial pass done (em-dashes, giving challenges) |
| **Scripture accuracy** | 🔴 **Blocked** | ~110 ESV fields are NIV text; NIV 1984 wording present — [spot check](../content/SCRIPTURE_SPOT_CHECK.md) |
| **Translation licensing** | 🔴 **Blocked** | Not cleared to ship as-is; permission inquiries or public-domain fallback needed — [licensing](../content/TRANSLATION_LICENSING.md) |
| Privacy policy URL | 🟡 Draft | Text drafted, needs review + public hosting — [PRIVACY_POLICY.md](PRIVACY_POLICY.md) |
| Signing / TestFlight | 🟡 Greg's clicks | Runbook ready; internal TestFlight possible anytime — [TESTFLIGHT_RUNBOOK.md](TESTFLIGHT_RUNBOOK.md) |
| CloudKit | ⚪ Deferred (v1.x) | v1 is local SwiftData only, by decision — [CLOUDKIT_DECISION.md](CLOUDKIT_DECISION.md) |
| Real badge art | 🟡 Outstanding | Recraft pack not commissioned; placeholder art ships internally fine |
| Marketing screenshots | 🟡 Planned | Sizes + storyboard documented; capture after content/icon final — [SCREENSHOTS_AND_ICON.md](SCREENSHOTS_AND_ICON.md) |
| App icon | 🟡 Placeholder | Navy/cross placeholder; final 1024×1024 needed before store |

**Bottom line:** the app is technically ready for an internal TestFlight build today (Greg's signing steps only). Public release is blocked on exactly two red items — scripture text accuracy and translation licensing — plus the mechanical yellows (privacy URL, icon, screenshots).

Honest launch checklist: [`sparc/completion/checklist.md`](../../sparc/completion/checklist.md).
