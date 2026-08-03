# Architecture

Status: **current.** Describes the code as it is, and is updated with it.

For the design *history* — how the app was originally specified, and which of
those decisions no longer hold — see [`sparc/`](../sparc/), which is marked
historical throughout.

## Shape

A single composition root builds one service graph per app session. Views own no
state beyond their own presentation; view models own no persistence.

```
FaithfullyApp
  └── PersistenceStack        opens the store, or degrades to in-memory
        └── AppEnvironment    composition root; loads content, bootstraps profile
              └── AppServices  the session graph
                    ├── ChallengeService     scheduling, completion, streaks
                    ├── BadgeService         evaluation and awards
                    ├── NotificationService  scheduling, serialized
                    └── four view models     one per tab
```

Everything is local. There is **no backend, no account, no network call, and no
third-party dependency.** Challenge content is a bundled JSON file.

## The five rules the code is built on

Each of these was a defect before it was a rule. They are listed here because
breaking one silently is easy and the consequences are not obvious.

### 1. A calendar date resolves to the same challenge for every user

Rotation is anchored to a fixed global epoch (`Constants.rotationEpochYear`),
never to the user's enrollment date. A per-user anchor would give two users
different challenges on the same day, which contradicts the product's central
promise.

`ChallengeScheduler.globalYearOffset(for:)` · pinned by
`ChallengeServiceTests.testEnrollmentDateDoesNotAffectWhichChallengeADateResolvesTo`

### 2. Enrollment is an eligibility boundary

A day before `enrollmentDate` is not missed — it is not the user's day at all. It
cannot be completed, earns no credit, and renders as `.preEnrollment` rather than
as a failure. The check runs *before* the grace window, so grace cannot backfill
history that predates the account.

`ChallengeService.completeChallenge` · `ChallengeServiceEnrollmentTests`

### 3. A completed day is a civil day, frozen at write time

`CompletedChallenge.dayKey` stores `yyyyMMdd`, derived once and never
recomputed. Storing an instant and re-deriving the day meant a completion could
move when the device's time zone did.

See [`architecture/TIMEZONE_POLICY.md`](architecture/TIMEZONE_POLICY.md) — read it before touching any date
logic. · `CivilDayTests`, `CivilDayMigrationTests`

### 4. A write either lands or is reported

`PersistenceCoordinator` is the only place SwiftData errors become typed
results. `transaction` rolls back on failure. A completion and the badges it
earns commit together — separately, a crash between them left a completion whose
badge was never awarded.

No `try?` remains on a user mutation. The single exception is launch badge
reconciliation, which is best-effort by design and says so at the call site.

`PersistenceFailureTests`

### 5. The journal is never silently altered

Over-limit text is rejected with a typed error, never truncated. The editor shows
the limit and blocks submission past it. The sheet clears the draft only on a
confirmed success.

`ChallengeServiceJournalTests` · `DailyWalkViewModelTests`

## Persistence

SwiftData, local only. Schema history and migration live in
`Faithfully/Models/SchemaVersions.swift`:

| Version | Change |
|---|---|
| V1 | Original models |
| V2 | Adds `CompletedChallenge.dayKey`, backfilled from the V1 instant |

`PersistenceStack.open()` returns `.ready` or `.degraded`. Degraded means the
on-disk store could not be opened: the app runs on an in-memory stand-in so the
user still gets today's challenge, shows a persistent banner saying nothing is
being saved, and offers to move the unreadable file aside — moved, never deleted.

## Concurrency

The app builds in **Swift 6 language mode** with zero project-owned warnings
under complete concurrency checking. CI enforces this.

`NotificationService` serializes all schedule/cancel work through a lock-guarded
chain. A lock rather than an actor because the ordering has to be established
synchronously, in call order, at the call site — hopping into an actor to link
the chain would put the linking itself on an unordered task queue.

Values crossing into that chain are `Sendable` by construction:
`NotificationPreferences` snapshots the seven fields the service actually reads,
so a SwiftData model never crosses a boundary.

## Content

365 challenges in `Faithfully/Resources/challenges.json`, each with a scripture
reference and text in two public-domain translations: **WEB** and **KJV**.

`scripts/validate_challenges.py` checks schema, count, and that the production
and test copies are identical. It runs in CI.

## What this app does not have

Listed because earlier design documents describe some of these as if they exist:

- **No CloudKit and no sync.** v1 is local-only, by decision — see
  [`ship/CLOUDKIT_DECISION.md`](ship/CLOUDKIT_DECISION.md).
- **No ESV, NIV, or NKJV.** Those are licensed translations; v1 ships
  public-domain WEB and KJV — see
  [`content/TRANSLATION_LICENSING.md`](content/TRANSLATION_LICENSING.md).
- **No `PersistenceService` with a `syncToCloudKit()` method.** Persistence is
  `PersistenceCoordinator`, which is local and synchronous.
- **No account, analytics, tracking SDK, or remote configuration.**

## Verification

Every gate is in the `Makefile` and runs identically locally and in CI:

```sh
make bootstrap && make ci
```

See [`ship/MERGE_CHECKLIST.md`](ship/MERGE_CHECKLIST.md) for what each check
covers — and, just as importantly, what it does not.
