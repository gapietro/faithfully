# Editing and deleting journal entries

Design, 2026-08-02. Approved before implementation.

Closes the gap recorded in `docs/ship/DATA_PROTECTION.md`: a user who writes
something they regret currently has no way to remove it short of deleting the
app.

## What this is

A user can change or clear the reflection attached to any completed day, and add
one to a day they completed without writing anything.

That is the whole feature. It is deliberately not a way to undo a completion.

## Decisions

**Delete removes the reflection text, not the completion.** The day stays
completed; streak, totals and badges are untouched. This is safe by
construction, not by care: nothing derived reads `journalEntry`. `BadgeEvaluator`
takes completion count, streak and per-category counts. `StreakCalculator` takes
day keys. Neither can see the text.

Deleting the whole completion is a different feature with a real unanswered
question — whether a badge already earned should be revoked when the user drops
below its threshold — and is out of scope.

**Two entry points, Calendar canonical.** Journey is where people browse their
writing, so a row is tap-to-edit with a visible delete button.

Not swipe-to-delete: `.swipeActions` only works inside a `List`, and the
timeline is a `ScrollView` of custom cards. Converting it would rewrite the
layout and the tests that walk it, to land a gesture that is less discoverable
and needs VoiceOver custom actions to be reachable at all. A 44pt button is
plainer.

But Journey only lists completions that *have* text:

```swift
guard let challenge = challengeMap[completion.challengeId],
      let journal = completion.journalEntry,
      !journal.isEmpty else { return nil }
```

So clearing an entry there removes it from the only list that showed it. Without
a second route the day becomes unreachable and the user can never write anything
for it again — a one-way door. Calendar day detail shows every completed day
regardless of text, so it is the canonical home and the only place an empty day
can be reached.

**Delete is guarded by a confirmation, not an undo.** The confirmation names the
date and says the day stays completed, because the streak is what people will
actually fear losing. An undo window would need a pending-delete buffer that
does not survive a background or a crash, which means the promise it makes is
not always true.

The confirmation is on the *destructive outcome*, not on one button. It appears
for the delete button in Journey, and equally when someone clears the text in the
editor and taps Save — that erases writing just as thoroughly, so it cannot be
the one path that skips the guard. Saving an edit that still has text does not
confirm.

Calendar day detail therefore needs no separate delete control: clearing in the
editor is the delete, and it is guarded.

**No time limit on editing.** It is the user's own writing.

## Architecture

### One new service method

```swift
func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult
```

on `ChallengeServiceProtocol`. `nil` clears. It runs inside
`PersistenceCoordinator.transaction`, inheriting the rollback and typed-error
contract established by CLEAN-004.

The alternative — mutating the model from the view models — was rejected: it
bypasses the persistence boundary and would put the length rule in two view
models. That is the shape the original truncation bug had.

```swift
enum JournalEditResult: Equatable {
    case saved
    case failed(JournalEditFailure)
}

enum JournalEditFailure: Equatable {
    case tooLong(limit: Int, actual: Int)
    case entryNotFound
    case couldNotSave

    /// User-facing text, as `CompletionFailure.message` does.
    var message: String
}
```

`CompletionFailure` is deliberately not reused. Its `.beforeEnrollment`,
`.gracePeriodExpired` and `.alreadyCompleted` cases cannot occur for an edit, and
a type whose cases cannot occur is a type that lies about its own contract.

### One shared validation rule

The 2,000-character rule is currently inline in `completeChallenge`. It moves to:

```swift
enum JournalText {
    /// Trims whitespace, treats empty as absent, rejects over-limit.
    /// Throws `JournalValidationError.tooLong(limit:actual:)`.
    static func validated(_ raw: String?) throws -> String?
}
```

Both `completeChallenge` and `updateJournal` call it. Completion and editing
cannot drift apart, and the CLEAN-003 guarantee — reject, never truncate — holds
on the new path without being restated.

### One shared editor

`CompletionSheetView` already carries the live counter, the over-limit submit
block, the accessible label on the `TextEditor`, the failure display that keeps
the draft, and the explicit `presentationBackground` that made its contrast
deterministic. That is the combined output of CLEAN-003 and OPS-004.

Its body is extracted into `JournalEditorView(text:errorMessage:)`, used by both
the completion sheet and the new edit sheet. Duplicating it would mean those
guarantees exist twice and rot independently.

The edit sheet differs from the completion sheet only in its title and its
primary action ("Save" rather than "Complete Challenge").

## Data flow

`journalEntry` is the only field that changes.

```
CompletedChallenge
  id             unchanged
  challengeId    unchanged
  dayKey         unchanged   <- streak and calendar grouping
  completedDate  unchanged   <- journal ordering
  scheduledDate  unchanged
  journalEntry   changed
```

Because nothing else moves, streak, total and badges cannot move either. That is
an invariant with a test, not an assumption.

After a successful edit both view models refresh. `JourneyViewModel.refresh()`
already rebuilds from `fetchAllCompletions()`; if a search is active the current
query is reapplied so the list does not silently reset to unfiltered.

## Error handling

Same posture as CLEAN-003: on any failure the sheet stays open and the draft is
preserved. **A failed edit must never destroy the text it was editing.**

| Failure | Cause | User sees |
|---|---|---|
| `tooLong` | Over 2,000 characters after trimming | Inline message; Save disabled while over |
| `entryNotFound` | The completion no longer exists | Message; sheet closes on dismiss |
| `couldNotSave` | Store write failed | Message; draft kept; retry available |

Delete uses the same path with `nil`, so a failed delete leaves the reflection
intact and says so.

## Testing

**Invariant — the point of the whole design:**

- editing a reflection leaves streak, total completed, and earned badges identical
- clearing a reflection does the same, and the calendar day keeps its
  `.completed` status and accessibility value

**Service:**

- 1,999 / 2,000 / 2,001 characters — the third rejected, nothing written
- clearing sets `journalEntry` to `nil`, not to an empty string
- whitespace-only text is treated as clearing
- unknown `entryID` returns `.entryNotFound` and writes nothing
- injected save failure returns `.couldNotSave` and rolls back, via
  `InjectablePersistence`

**View models:**

- a cleared entry disappears from `JourneyViewModel.journalEntries`
- an edited entry keeps its position in the timeline (ordering is by
  `completedDate`, which does not change)
- an active search is reapplied after an edit
- Calendar day detail reflects an edit without a relaunch

**UI:**

- edit from Journey, relaunch, text persisted
- delete from Journey: gone from the list, day still shows completed in Calendar,
  Journey total unchanged
- add a reflection from Calendar to a day that had none, then find it in Journey
- over-limit text blocks Save
- accessibility audit passes on the edit sheet

## Out of scope

- Undoing a completion
- Version history or an edit trail. This is a private local journal; recording
  that someone revised a confession works against the point of letting them.
- Per-entry export. `ShareLink` already covers sharing.

## Consequences to record on landing

`docs/ship/DATA_PROTECTION.md` currently states per-entry deletion is not
supported and flags it as needing a product decision. That row and the
corresponding line in `docs/ship/README.md` are updated by this work, and
`docs/ship/CLAIMS.md` gains a row for the new promise.
