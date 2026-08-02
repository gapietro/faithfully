# Time-zone and calendar-day policy

Status: current. Introduced by CLEAN-005 (audit tracker #39, issue #45).

This document is the single answer to "which day is this?" Anything in the code
that decides what day a completion belongs to must follow it.

## The rule

> A completion is recorded against **the user's local calendar day at the moment
> they complete it**, and that day is then frozen. It is never recomputed.
>
> "Today" is always the user's **current** local calendar day.

Both halves matter. The first keeps history stable. The second keeps the app
honest about where the user is now.

## Why an instant is not a day

Before CLEAN-005, a completion stored `scheduledDate.startOfDay` — an absolute
`Date` — and every later read reinterpreted it through whatever
`Calendar.current` the device happened to have.

That works until the device's calendar changes. Complete a challenge just after
midnight in Auckland and fly to Honolulu, 22 hours behind: the same instant is
now the *previous* calendar day. The completion moves in the calendar grid, can
fall outside the month query that should contain it, and the streak breaks for a
day the user did not miss.

An instant answers "when did this happen". A civil day answers "which day was
it". They are different questions, and only the second one is stable.

## The representation

`CivilDay` produces an `Int` key in `yyyyMMdd` form — `20260615` for 15 June
2026. Stored on `CompletedChallenge.dayKey`.

Why an `Int` rather than a struct:

- it sorts chronologically as an integer, so range queries are plain comparisons
- it is usable directly in a SwiftData `#Predicate`, which an opaque type is not
- it is readable in a debugger and in the store file

## Consequences you must respect

**Day arithmetic goes through the calendar, never through seconds.** A DST day
is 23 or 25 hours long. Subtracting 86,400 seconds skips or repeats a day twice
a year. Use `CivilDay.key(_:offsetByDays:)`.

**`CivilDay.date(for:)` anchors at noon**, so a DST transition at or near
midnight cannot push the representative instant into an adjacent day.

**Reads never re-derive the day.** `dayKey` is read back verbatim. If you find
yourself calling `startOfDay` on a stored `scheduledDate` to decide which day a
completion belongs to, you have reintroduced the bug.

**`completedDate` is not a day.** It is the instant the user tapped complete,
used only for ordering the journal.

## What is deliberately *not* solved

A user who changes time zone mid-day sees "today" change according to their new
local calendar. That is intended: they really are on a new local day. Only
already-recorded days are frozen.

The app does not store the originating time zone. It stores the day that zone
produced, which is the fact the product actually cares about. If a future feature
needs to display "you completed this at 7am in Auckland", the time zone would
have to be added alongside `dayKey` — but that is a display concern, not an
identity one, and must not become the identity again.

## Schema

`dayKey` arrived in schema V2. See `FaithfullyMigrationPlan`:

- the V1 → V2 stage backfills `dayKey` from the V1 `scheduledDate` using the
  calendar in force at migration time — the same interpretation V1 itself would
  have produced on that device, so nothing shifts underneath an existing user
- `dayKey` carries a schema default of `0`. This is load-bearing: without it, the
  mandatory attribute cannot be added to existing rows and the store fails to
  open *before* `didMigrate` can run
- `0` therefore means "not yet backfilled", never "the year zero".
  `FaithfullyMigrationPlan.backfillDayKeys` repairs such rows and runs on every
  launch, because a store created before the plan existed reaches V2 without
  passing through the stage

Rollback is safe: `dayKey` is additive, so a V1 build can still open a migrated
store and simply ignores the column. Covered by
`CivilDayMigrationTests.testAV1BuildCanStillOpenAMigratedStore`.

## Tests that hold this in place

`CivilDayTests` — key derivation, chronological ordering, leap-day round trip,
spring-forward and fall-back arithmetic, the date-line regression, streak
survival across a zone change, and a guard that streaks still break on a
genuinely missed day.

`CivilDayMigrationTests` — real on-disk V1 → V2 migration, field preservation,
reopen without re-migrating, empty store, backfill repair and idempotency, and
V1 rollback.
