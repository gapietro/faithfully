# Ship Readiness

**Status: current.** This page is the single answer to "is it ready?"; everything
linked from here is detail. Last reviewed 2026-08-02, after the post-audit
remediation (tracker [#39](https://github.com/gapietro/faithfully/issues/39)).

## Bottom line

**Internal TestFlight: ready.** Everything verifiable without a device or an App
Store Connect session is verified, and enforced on every pull request.

**Public release: not yet.** Four things remain, none of them code — a signed
build validated on real hardware, a device accessibility pass, performance
measured on representative hardware, and crash reporting with a named support
owner. Tracked as #52 through #56.

## Where to look

| Question | Answer |
|---|---|
| What passes right now? | `make ci` — [MERGE_CHECKLIST.md](MERGE_CHECKLIST.md) |
| How is it built? | [ARCHITECTURE.md](../ARCHITECTURE.md) |
| Which public promises are actually proven? | [CLAIMS.md](CLAIMS.md) |
| How do I get a build onto a phone? | [TESTFLIGHT_RUNBOOK.md](TESTFLIGHT_RUNBOOK.md) |
| Why is a date handled that way? | [TIMEZONE_POLICY.md](../architecture/TIMEZONE_POLICY.md) |

## Status

| Area | Status | Notes |
|---|---|---|
| Code & tests | 🟢 Ready | 246 unit + 36 UI tests, enforced by CI on every PR |
| Audit findings | 🟢 Resolved | All 12 remediated with regression tests — [#39](https://github.com/gapietro/faithfully/issues/39) |
| Quality gate | 🟢 Ready | Pinned tooling, `make ci`, GitHub Actions — [MERGE_CHECKLIST.md](MERGE_CHECKLIST.md) |
| Concurrency | 🟢 Ready | Swift 6 language mode, zero project-owned warnings |
| Design pass 1 | 🟢 Ready | Sprint C brand assets, motion, badge names in place |
| Content editorial | 🟢 Ready | Sprint D editorial pass done (em-dashes, giving challenges) |
| Scripture accuracy | 🟢 Ready | Public-domain WEB + KJV, 251/251 refs resolved, spot check 24/24 — [PD spot check](../content/SCRIPTURE_SPOT_CHECK_PD.md) |
| Translation licensing | 🟢 Ready | Cleared for v1 under the public-domain strategy (#22) — [licensing](../content/TRANSLATION_LICENSING.md) |
| Privacy policy URL | 🟢 Ready | Live public gist + in-app Settings link — [PRIVACY_POLICY.md](PRIVACY_POLICY.md) · [HTML](../privacy/index.html) |
| Marketing screenshots | 🟢 Ready | 6× 1320×2868 PNGs — [screenshots/6.9/](screenshots/6.9/) |
| App icon | 🟢 Ready | Recraft v3 open-book + cross — [icons/README.md](icons/README.md) |
| Device family | 🟢 Ready | iPhone-only, asserted against the built archive in CI |
| CloudKit | ⚪ Deferred (v1.x) | v1 is local SwiftData only, by decision — [CLOUDKIT_DECISION.md](CLOUDKIT_DECISION.md) |
| Real badge art | 🟡 Outstanding | Recraft pack not commissioned; placeholder art ships internally fine |
| Branch protection | 🟡 Blocked | Unavailable on this repo's plan: CI runs but cannot block a merge — [MERGE_CHECKLIST.md](MERGE_CHECKLIST.md) |
| Signing / TestFlight / App Store validation | 🔴 Unverified | Archive is built unsigned; nothing has been uploaded — [#52](https://github.com/gapietro/faithfully/issues/52) |
| Crash reporting & support ownership | 🔴 Not defined | No way to learn about a crash in the field — [#53](https://github.com/gapietro/faithfully/issues/53) |
| Data protection & deletion | 🔴 Unverified | File-protection class not inspected on device — [#54](https://github.com/gapietro/faithfully/issues/54) |
| Device accessibility | 🔴 Unverified | No VoiceOver / Dynamic Type pass on hardware — [#55](https://github.com/gapietro/faithfully/issues/55) |
| Device performance | 🔴 Unmeasured | No launch, scroll, memory, or energy budgets — [#56](https://github.com/gapietro/faithfully/issues/56) |

🔴 items are the public-release gate. None can be closed from a laptop.

## Historical documents

The [`sparc/`](../../sparc/) tree records the original design phase and is marked
historical throughout. It still describes CloudKit sync and the ESV/NIV/NKJV
translations — neither of which v1 has. Read [ARCHITECTURE.md](../ARCHITECTURE.md)
instead.

[`sparc/completion/checklist.md`](../../sparc/completion/checklist.md) was the
launch checklist through Sprint E. Superseded by this page plus
[MERGE_CHECKLIST.md](MERGE_CHECKLIST.md); kept for the record.

[SESSION_HANDOFF.md](SESSION_HANDOFF.md) and [TEST_RUN.md](TEST_RUN.md) are
point-in-time snapshots that predate Sprint F and the audit remediation. Test
counts in them are stale by design; `make ci` is the live number.
