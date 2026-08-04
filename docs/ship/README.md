# Ship Readiness

**Status: current.** This page is the single answer to "is it ready?"; everything
linked from here is detail. Last reviewed 2026-08-03, after the second
senior-grade pass — 86/100 (B), up from 77 (C+). Tracker
[#39](https://github.com/gapietro/faithfully/issues/39); full scorecard in
[`AUDIT.md`](../../AUDIT.md).

## Bottom line

**Internal TestFlight: ready.** Everything verifiable without a device or an App
Store Connect session is verified by `make ci`. Running it before a merge is
policy, not mechanism — hosted CI is manual-only and branch protection is
unavailable on this plan, so nothing blocks a merge past a failing gate. See
[MERGE_CHECKLIST.md](MERGE_CHECKLIST.md).

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
| What happens to a user's data? | [DATA_PROTECTION.md](DATA_PROTECTION.md) |
| Something broke in the field — now what? | [OPERATIONS.md](OPERATIONS.md) |

## Status

| Area | Status | Notes |
|---|---|---|
| Code & tests | 🟢 Ready | Unit, UI, and accessibility suites all green in `make ci`; `make ci` is the live count, so none is quoted here |
| Audit findings | 🟡 Second pass open | All 12 from the first pass remediated with regression tests and re-verified. The 2026-08-03 pass raised seven more, none a release blocker — [#39](https://github.com/gapietro/faithfully/issues/39) |
| Quality gate | 🟢 Ready | Pinned tooling, `make ci`. Hosted CI is manual-only by decision — [MERGE_CHECKLIST.md](MERGE_CHECKLIST.md) |
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
| Merge enforcement | 🟡 By policy | Branch protection is unavailable on this plan and hosted runs are not being scheduled; `make ci` on a dev machine is the gate, by decision — [MERGE_CHECKLIST.md](MERGE_CHECKLIST.md) |
| Signing / TestFlight / App Store validation | 🔴 Unverified | Archive is built unsigned; nothing has been uploaded — [#52](https://github.com/gapietro/faithfully/issues/52) |
| Crash reporting & support ownership | 🟡 Drafted, 3 decisions open | Runbook written; needs a crash-reporting choice, a support address, and an owner — [OPERATIONS.md](OPERATIONS.md) · [#53](https://github.com/gapietro/faithfully/issues/53) |
| Data protection | 🟡 Set, unverified on device | Store opens at `.complete`; privacy manifest shipped. On-device confirmation outstanding — [DATA_PROTECTION.md](DATA_PROTECTION.md) · [#54](https://github.com/gapietro/faithfully/issues/54) |
| Journal edit and delete | 🟢 Ready | Edit, clear, or add a reflection from Journey or Calendar; the completion is never touched — [DATA_PROTECTION.md](DATA_PROTECTION.md) |
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
