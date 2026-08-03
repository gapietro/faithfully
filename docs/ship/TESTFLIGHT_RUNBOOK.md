# TestFlight Runbook — for Greg

Step-by-step path from this repo to a TestFlight build. **Nothing here has been executed** — Sprint E prepared the repo so these clicks are all that's left.

> **Hard rule:** Scout/agents must not create App Store Connect records, upload builds, or submit anything. Every step below is Greg's to run. Internal TestFlight is fine when Greg chooses; **external/public TestFlight and App Store submission are blocked** until the blockers at the bottom are cleared.

## One-time setup

1. **Apple Developer Program** — enroll (or confirm active membership) at developer.apple.com with the Apple ID you'll ship under ($99/yr).
2. **Register the bundle ID** — in [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers), register `com.faithfully.app` (App IDs → App; no extra capabilities needed for v1 — no iCloud, since CloudKit is deferred).
3. **Create the app record** — in [App Store Connect → My Apps → "+"](https://appstoreconnect.apple.com): platform iOS, name **Faithfully** (adjust if taken), primary language English (U.S.), bundle ID `com.faithfully.app`, SKU e.g. `faithfully-ios-1`.

## Per-build: archive and upload

4. **Generate and open the project** — `xcodegen generate`, then open `Faithfully.xcodeproj` in Xcode.
5. **Set the signing team** — target *Faithfully* → Signing & Capabilities → check *Automatically manage signing*, select your Team. (`project.yml` already sets `CODE_SIGN_STYLE: Automatic`; the team can also be pinned there later via `DEVELOPMENT_TEAM` once you know the ID, so xcodegen regeneration doesn't drop it.)
6. **Sanity-check versioning** — Marketing version `1.0`, build `1` (already in `project.yml`; bump `CURRENT_PROJECT_VERSION` for each new upload).
7. **Archive** — select destination *Any iOS Device (arm64)*, then Product → Archive.
8. **Upload** — in the Organizer window: Distribute App → App Store Connect → Upload, accept defaults (automatic signing, symbols included). Export compliance: the app uses only standard iOS encryption (HTTPS/none) — answer "None of the algorithms mentioned" / exempt.
9. **Wait for processing** — the build appears in App Store Connect → TestFlight in ~5–30 min.

## Internal TestFlight (OK to do anytime)

10. In App Store Connect → TestFlight, complete the export-compliance question on the build if prompted.
11. Add yourself (and any team members with ASC roles) to an **internal** group and enable the build. Internal testing needs no Apple review and none of the blockers below apply — this is the fastest way to get Faithfully on your phone.

## ⛔ Blockers before external/public TestFlight or App Store

External TestFlight goes through App Review. Do **not** start it until all of these are cleared:

1. ~~**Scripture licensing / accuracy**~~ — **Cleared for v1** under public-domain WEB + KJV (`docs/content/TRANSLATION_LICENSING.md`, PR #34).
2. ~~**Privacy policy hosted URL**~~ — **Live:** https://gist.github.com/scoutapietro/96c48a68f12efe3950b5bc359db70974 (paste into App Store Connect Privacy Policy field).
3. ~~**Screenshots**~~ — **Done** (Sprint F2, PR #38): 6.9" set captured in `docs/ship/screenshots/6.9/`.
4. ~~**Real app icon**~~ — **Done** (Sprint F, PR #36): Recraft v3 art shipped.
5. **Signed build validated on a physical device** — the archive is built unsigned in CI; signing, upload, and App Store validation are still unverified. *(issue #52)*
6. **Device accessibility and performance passes.** *(issues #55, #56)*
7. **Crash reporting and support ownership defined** before anyone outside the team relies on the app. *(issue #53)*
8. **Explicit Greg OK** before external TF / Submit for Review. *(issue #28)*

Internal TestFlight (#27) does **not** require #5–8.

## Reference

- Listing copy drafts: `docs/ship/APP_STORE_LISTING.md`
- Privacy policy draft: `docs/ship/PRIVACY_POLICY.md`
- Test evidence: `docs/ship/TEST_RUN.md`
- CloudKit deferral: `docs/ship/CLOUDKIT_DECISION.md`
