# Local data: protection, backup, deletion

Status: current. Introduced by OPS-003 (audit tracker #39, issue #54).

What Faithfully stores, where, how well it is protected, and what happens to it.
Written because "it's all local" is a claim, not a policy, and the audit could
not verify any of it.

## What is stored

Everything lives in one local SwiftData store. There is no backend, no account,
no network call, and no third-party SDK — the audit's full-tree and full-history
scan confirmed this.

| Data | Sensitivity |
|---|---|
| Journal entries | **High.** Private religious reflection: confession, doubt, who someone is struggling to forgive |
| Completions (day, challenge, category) | Moderate — reveals religious practice and its consistency |
| Earned badges | Low |
| Preferences (translation, reminder times, appearance) | Low |
| `hasCompletedOnboarding` | Trivial. The only thing in `UserDefaults` |

Notification text is deliberately generic ("Today's challenge is waiting for
you") and never contains challenge or journal content, so nothing sensitive
appears on a locked screen.

## Protection at rest

The store is opened with **`FileProtectionType.complete`**
(`PersistenceStack.storeProtection`). The file is encrypted and unreadable
whenever the device is locked.

iOS defaults app-container files to `completeUntilFirstUserAuthentication` —
readable from the first unlock after boot until the device powers off. That is
a sensible default for most data and the wrong one for a journal. A lost phone
that has been unlocked once since boot would otherwise give up its contents.

`.complete` is safe **for this app specifically** because it never runs outside
the foreground: no background modes, no background fetch, no app extensions.
Notifications are handed to the system in advance and fire without touching the
store.

> **Adding any background work means revisiting this.** Under `.complete`, a
> file access while the device is locked fails. If Faithfully ever gains a
> background refresh, a widget, or a notification service extension, that code
> will not be able to read the store, and the protection class has to be
> reconsidered deliberately rather than discovered through a crash.

The three SQLite files are all protected — the main store plus the `-shm` and
`-wal` sidecars. Protecting only the main file would leave the most recently
written journal entry less protected than the rest.

Applying protection is best-effort and retried on every launch: the store is
already open by that point, and failing to raise protection is not a reason to
deny someone their app.

## Backup

The store sits in Application Support inside the app container, so it **is**
included in iCloud and encrypted local device backups. This is intentional:
without sync, a device backup is the only way a user's journal survives a lost
phone.

The consequence to be honest about: journal content leaves the device as part of
an iCloud backup, protected by Apple's backup encryption rather than by this
app. `PRIVACY_POLICY.md` must not claim the data never leaves the device.

## Deletion

| Action | Effect |
|---|---|
| Delete the app | The whole container goes, including the store. Complete and immediate |
| "Reset Saved Data" on the store-unavailable banner | Moves the unreadable store aside and starts fresh. **Moves, never deletes** — an unreadable file may still be recoverable by hand, and deleting it outright would discard the only copy of the journal |
| Delete a single journal entry | **Not supported.** A completion cannot currently be undone or edited |

That last row is a real gap for a journal app. Someone who writes something they
regret has no way to remove it short of deleting the app. Worth a product
decision before public release.

## Privacy manifest

`Faithfully/Resources/PrivacyInfo.xcprivacy` declares:

- `NSPrivacyTracking`: false, with no tracking domains
- `NSPrivacyCollectedDataTypes`: empty — nothing is collected
- One accessed API: `UserDefaults`, reason **CA92.1** (app-only, not shared),
  used by `@AppStorage("hasCompletedOnboarding")`

Empty arrays are declared rather than omitted. An empty declaration is a
statement; a missing one is a gap.

## What is verified, and how

| Claim | Verified by |
|---|---|
| Protection class is `.complete`, not the OS default | `DataProtectionTests.testStoreProtectionIsCompleteAndNotTheOSDefault` |
| Manifest declares no tracking and no collection | `DataProtectionTests.testPrivacyManifestDeclaresNoTrackingAndNoCollection` |
| Manifest declares the UserDefaults reason | `DataProtectionTests.testPrivacyManifestDeclaresTheUserDefaultsReason` |
| No network code exists | Audit full-tree scan; no URLSession, no third-party package |

## Still unverified — needs a device

These cannot be checked from a simulator, which has no hardware key hierarchy
and does not even report the protection attribute back. Tracked in **#54**:

- [ ] Confirm on-device that the store is genuinely unreadable while locked
- [ ] Confirm the `-shm` and `-wal` sidecars carry the same class after real use
- [ ] Confirm a restored iCloud backup brings the journal back intact
- [ ] Confirm App Store validation accepts the privacy manifest (**#52**)
- [ ] Decide whether per-entry deletion ships in v1
