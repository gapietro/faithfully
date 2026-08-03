# Operations: crash reporting, support, triage, rollback

Status: **draft — three decisions are yours.** Introduced by OPS-002 (audit
tracker #39, issue #53).

The audit's question was blunt: *can operators detect, diagnose, and recover?*
The answer was no. There is no way to learn that Faithfully crashed on someone's
phone, nobody named to hear about it, and no procedure for either. This
document is the procedure. It is a draft because it names three things only you
can decide, marked **`DECIDE:`** throughout.

Until those are filled in, this is not a runbook — it is a form.

---

## 1. Detecting a crash

> **`DECIDE:` how crashes reach you.**

| Option | What you get | Cost |
|---|---|---|
| **MetricKit + Xcode Organizer** *(recommended)* | Apple's own crash and hang reports, aggregated in Organizer. No SDK, no third party, no data leaves Apple's pipeline, nothing to declare in the privacy manifest | Free. Opt-in per user via "Share With App Developers"; you see a sample, not everything. Delayed by up to a day |
| **A third-party SDK** (Sentry, Crashlytics…) | Immediate, complete, with breadcrumbs and search | An SDK that sees your users' devices. Requires privacy-manifest changes, a new App Store privacy answer, and contradicts the current "no third-party SDKs, nothing leaves the device" position |

The recommendation is MetricKit, and not only because it is cheaper. This app's
entire privacy posture — no account, no analytics, nothing transmitted — is a
feature people can verify. A crash SDK trades that for diagnostics on an app
with four screens and no network calls. The trade is not obviously worth it.

**If MetricKit:** subscribe an `MXMetricManagerSubscriber` at launch and log
`MXDiagnosticPayload` crash and hang reports. Roughly 40 lines. Say the word and
I will add it.

**Where to look, either way:** Xcode → Window → Organizer → Crashes, filtered to
the current build. Check it on a schedule; nothing pushes to you.

## 2. Who hears about problems

> **`DECIDE:` a support address, and who owns it.**

- Support URL or email: **`DECIDE:`** — required by App Store Connect; there is
  currently no value for this field
- Owner: **`DECIDE:`** — the person who reads it
- Response expectation: **`DECIDE:`** — set one you will actually meet. For a
  solo app, "within a week" honestly stated beats "24 hours" aspirationally

Add the same address in-app under Settings → About, next to the privacy policy
link. A user who cannot find how to report a problem does not report it; they
leave a one-star review instead.

## 3. Triage

Symptom → likely cause → action. Everything here is grounded in a failure mode
the code actually has.

| Symptom | Likely cause | First check | Action |
|---|---|---|---|
| "My data is gone" / banner says data isn't available | Store failed to open — corruption, disk full, or a failed migration | Ask whether the orange banner is showing | The unreadable file is **moved aside, not deleted** (`Faithfully-unreadable-*.store` in Application Support). It may be recoverable via the Files app or a device backup. Do not tell the user to reinstall — that destroys it |
| "It says today is the wrong day" | Time-zone or DST edge | Which time zone, and did they travel? | Completed days are frozen at write time by design (`TIMEZONE_POLICY.md`). "Today" follows the device. If a *recorded* day moved, that is a real bug — get the date and zone |
| "My streak reset and I didn't miss a day" | Genuine miss, or a `dayKey` defect | Which dates, which time zone | Compare against `StreakCalculator`. `CivilDayTests` covers the known cases; a case outside them is new |
| "I completed it but the badge didn't appear" | Should be impossible since #64 — completion and badges are one transaction, and launch reconciles | Ask them to force-quit and reopen | Reconciliation runs on launch and is idempotent. If it persists, the transaction boundary is broken |
| "My journal entry was cut off" | Should be impossible since #60 — over-limit text is rejected, never truncated | How long was it, and did they see a counter | If text was silently lost, that is a P1 regression |
| Crash on launch | Corrupt store, or a migration defect | Organizer crash report | The store no longer crash-loops: an unopenable store degrades to in-memory with a banner. A launch crash means something else |
| Notifications not arriving | Permission denied, or Settings toggles off | iOS Settings → Faithfully → Notifications | Requests are scheduled even after denial, and fire once permission is granted, without needing another pass |

## 4. Rollback

There is no server, so "rollback" means one of three things.

**A bad build is on TestFlight.** Expire it in App Store Connect and distribute
the previous build. Immediate.

**A bad build is live on the App Store.** You cannot un-ship it. You can:

1. **Remove it from sale** — stops new installs; does nothing for people who
   already have it
2. **Submit a fix with an expedited review request** — hours to a day or two,
   and the only path that helps existing users
3. **Phased release** — if enabled, pause it. This only helps if it was enabled
   *before* the bad build went out, so enable it by default

**A bad migration shipped.** The worst case, because it touches data rather than
code. Schema migrations are additive and V1 can still open a V2 store
(`CivilDayMigrationTests.testAV1BuildCanStillOpenAMigratedStore`), so a
downgraded build reads its data and ignores the new column. Verify this
explicitly for any *future* migration before shipping it — the guarantee is a
property of each migration, not of the app.

## 5. Before a release

- [ ] `make ci` green on the release commit
- [ ] Version and build number bumped in `project.yml`
- [ ] Installed from TestFlight on a real device and exercised end to end
- [ ] Upgrade tested from the previous build with existing data, not a fresh install
- [ ] Organizer checked for crashes in the outgoing build
- [ ] Phased release enabled

## 6. Exercising this document

**A runbook nobody has run is fiction.** Before relying on any of it, prove the
recovery path works, on a device:

1. Install, complete a few days, write a journal entry
2. Corrupt the store deliberately — overwrite `default.store` with junk via the
   container in Xcode → Devices
3. Launch. Confirm the app **starts** rather than crash-looping, shows the
   orange banner, and still serves today's challenge
4. Use "Reset Saved Data". Confirm the app recovers, and that the old file is
   still present as `Faithfully-unreadable-*.store`
5. Record the result and the date here

Result: **`DECIDE:` not yet performed.**

## Open decisions, collected

1. **Crash reporting:** MetricKit, or a third-party SDK?
2. **Support address and owner:** what, and who?
3. **Response expectation:** what will you actually meet?

Until (1) and (2) are answered, the audit's operations grade cap stands, and
`docs/ship/README.md` correctly shows public release as blocked.
