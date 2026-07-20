# CloudKit Decision — Deferred to post-v1

**Decision (Sprint E, 2026-07-20): Faithfully v1 ships with local SwiftData persistence only. CloudKit sync is deferred to a v1.x release.**

## Why defer

1. **The offline-first MVP already works without it.** The full challenge library is bundled, all completion/journal/badge data persists locally in SwiftData, and every feature operates with no network. CloudKit was always specified as additive (PRD §6.4: "CloudKit sync is additive — for backup/restore and future multi-device").
2. **No entitlements or container exist today.** The project has no iCloud entitlement, no CloudKit container, and no sync code. Shipping it in v1 would mean net-new infrastructure, new failure modes (quota, conflicts, account state), and new test surface during ship prep.
3. **Smaller App Review and privacy surface.** Without CloudKit the privacy story is one sentence: data never leaves the device. No iCloud edge cases for Review to poke at, no sync rows in the privacy nutrition label.
4. **Multi-device sync is not a launch requirement.** The audit concluded single-device usage with local persistence is sufficient for v1. Backup/restore via iCloud device backup still covers the common "new phone" case at the OS level (SwiftData store is in the app container, which is included in device backups).

## What this means

- v1 data lives on-device only; deleting the app deletes history (this is stated in the privacy policy draft).
- PRD §6 references to CloudKit are future-facing; a v1 scope note has been added there.
- `sparc/completion/checklist.md` §9 (CloudKit) is marked **Deferred (v1.x)** — it is not an unchecked launch blocker.

## Revisit criteria (v1.x)

Pick CloudKit back up when any of these become priorities: multi-device usage, cloud restore independent of device backup, or remote content updates (PRD §6.3 mentions updating challenges.json via CloudKit). At that point: add the iCloud capability + container, adopt SwiftData's CloudKit mirroring (or CKSyncEngine), and complete checklist §9 before enabling.
