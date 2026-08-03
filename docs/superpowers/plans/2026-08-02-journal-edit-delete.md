# Journal Edit and Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user change, clear, or add the reflection on any completed day, without ever touching the completion itself.

**Architecture:** One new method on `ChallengeServiceProtocol` writes `journalEntry` inside a `PersistenceCoordinator` transaction. A shared `JournalText` validator serves both the completion path and the edit path, so the 2,000-character rule exists once. The editor UI is extracted from `CompletionSheetView` into a shared `JournalEditorView` so the counter, limit-blocking, accessibility, and contrast fixes are reused rather than copied.

**Tech Stack:** Swift 6 language mode, SwiftUI, SwiftData, XCTest + XCUITest.

## Global Constraints

- **Swift 6 language mode.** `SWIFT_VERSION = 6.0` on all three targets. Zero project-owned warnings under `SWIFT_STRICT_CONCURRENCY=complete` — this is enforced by `make ci`.
- **`swiftlint --strict` must pass, 0 violations.** No rule may be disabled. Relevant limits: files ≤ 400 lines, type bodies ≤ 350 lines (250 for the default), function bodies ≤ 50 lines, no `try!`, no implicitly-initialised optionals (`var x: T? = nil` is a violation — write `var x: T?`).
- **Never truncate journal text.** Over-limit input is rejected with a typed error. This is the CLEAN-003 guarantee and it must hold on the new path.
- **Never destroy a draft on failure.** Any failed save leaves the sheet open with the user's text intact.
- **No `try?` on a user mutation.** All writes go through `PersistenceCoordinator.transaction`, which rolls back on failure.
- **Never regenerate the project by hand.** Run `make generate` after adding files; `make verify-project` must report no drift.
- **The gate is `make ci` locally.** Hosted CI is `workflow_dispatch` only. Nothing merges without a green local run.
- Character limit is `Constants.maxJournalLength` (2,000). Never hard-code `2000`.

---

## File Structure

**Create:**
- `Faithfully/Utilities/JournalText.swift` — trimming + length validation, used by both write paths
- `Faithfully/Models/Results/JournalEditResult.swift` — `JournalEditResult`, `JournalEditFailure`
- `Faithfully/Views/Shared/JournalEditorView.swift` — the editor body shared by both sheets
- `Faithfully/Views/Shared/JournalEditSheet.swift` — the edit sheet (title + Save + confirmation)
- `FaithfullyTests/JournalTextTests.swift`
- `FaithfullyTests/JournalEditTests.swift`
- `FaithfullyUITests/JournalEditUITests.swift`

**Modify:**
- `Faithfully/Services/ChallengeService.swift` — protocol method, implementation, use `JournalText`
- `Faithfully/Views/DailyWalk/CompletionSheetView.swift` — delegate to `JournalEditorView`
- `Faithfully/Models/Results/CalendarDay.swift` — add `completionID`
- `Faithfully/ViewModels/CalendarViewModel.swift` — populate `completionID`, expose `updateJournal`
- `Faithfully/ViewModels/JourneyViewModel.swift` — expose `updateJournal`, preserve active search
- `Faithfully/Views/Journey/JourneyView.swift` — tap-to-edit, delete button, confirmation
- `Faithfully/Views/Calendar/DayDetailView.swift` — Edit / Add reflection
- `Faithfully/Views/Calendar/CalendarScreenView.swift` — present the edit sheet
- `FaithfullyTests/DailyWalkViewModelTests.swift` — `StubChallengeService` conformance
- `project.yml` is untouched; new files are picked up by the existing `Faithfully` source glob. Only `make generate` is needed.

---

### Task 1: Shared journal validation

Extracts the 2,000-character rule out of `completeChallenge` so one implementation serves both write paths.

**Files:**
- Create: `Faithfully/Utilities/JournalText.swift`
- Modify: `Faithfully/Services/ChallengeService.swift`
- Test: `FaithfullyTests/JournalTextTests.swift`

**Interfaces:**
- Consumes: `Constants.maxJournalLength`
- Produces:
  - `enum JournalValidationError: Error, Equatable { case tooLong(limit: Int, actual: Int) }`
  - `enum JournalText { static func validated(_ raw: String?) throws -> String? }`

- [ ] **Step 1: Write the failing test**

Create `FaithfullyTests/JournalTextTests.swift`:

```swift
import XCTest
@testable import Faithfully

final class JournalTextTests: XCTestCase {

    private func text(ofLength length: Int) -> String {
        String(repeating: "a", count: length)
    }

    func testNilAndEmptyBecomeAbsent() throws {
        XCTAssertNil(try JournalText.validated(nil))
        XCTAssertNil(try JournalText.validated(""))
        XCTAssertNil(try JournalText.validated("   \n  "),
                     "Whitespace-only is not a reflection")
    }

    func testTextIsTrimmedButOtherwiseUntouched() throws {
        XCTAssertEqual(try JournalText.validated("  Grateful today.  \n"), "Grateful today.")
    }

    func testTextAtAndBelowTheLimitIsAccepted() throws {
        let atLimit = text(ofLength: Constants.maxJournalLength)
        XCTAssertEqual(try JournalText.validated(atLimit)?.count, Constants.maxJournalLength)

        let belowLimit = text(ofLength: Constants.maxJournalLength - 1)
        XCTAssertEqual(try JournalText.validated(belowLimit)?.count, Constants.maxJournalLength - 1)
    }

    func testTextOverTheLimitIsRejectedNotTruncated() {
        let over = text(ofLength: Constants.maxJournalLength + 1)
        XCTAssertThrowsError(try JournalText.validated(over)) { error in
            XCTAssertEqual(
                error as? JournalValidationError,
                .tooLong(limit: Constants.maxJournalLength, actual: Constants.maxJournalLength + 1)
            )
        }
    }

    func testLengthIsJudgedAfterTrimming() throws {
        // Trailing whitespace must not cost the user their reflection.
        let padded = text(ofLength: Constants.maxJournalLength) + "\n   \n"
        XCTAssertEqual(try JournalText.validated(padded)?.count, Constants.maxJournalLength)
    }

    func testErrorReportsTheActualLength() {
        let actual = Constants.maxJournalLength + 137
        XCTAssertThrowsError(try JournalText.validated(text(ofLength: actual))) { error in
            guard case .tooLong(_, let reported) = (error as? JournalValidationError) else {
                return XCTFail("Expected tooLong, got \(error)")
            }
            XCTAssertEqual(reported, actual, "The user must be told how far over they are")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make generate
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyTests/JournalTextTests test
```

Expected: FAIL — `cannot find 'JournalText' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Faithfully/Utilities/JournalText.swift`:

```swift
import Foundation

enum JournalValidationError: Error, Equatable {
    case tooLong(limit: Int, actual: Int)
}

/// The single rule for turning raw editor text into something storable.
///
/// This lived inline in `completeChallenge`. Editing needs exactly the same
/// rule, and two copies of a length check is how the original truncation bug
/// would come back on the new path while the old one stayed fixed.
enum JournalText {
    /// Trims whitespace, treats an empty result as absent, and rejects
    /// over-limit text.
    ///
    /// Rejects rather than truncates: silently dropping the tail of a private
    /// reflection is data loss the user never consented to and cannot detect.
    /// Length is judged *after* trimming, so a trailing newline never costs
    /// someone their entry.
    static func validated(_ raw: String?) throws -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }

        guard trimmed.count <= Constants.maxJournalLength else {
            throw JournalValidationError.tooLong(
                limit: Constants.maxJournalLength,
                actual: trimmed.count
            )
        }
        return trimmed
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: PASS, 6 tests.

- [ ] **Step 5: Route `completeChallenge` through it**

In `Faithfully/Services/ChallengeService.swift`, replace this block inside `completeChallenge`:

```swift
        // Length is judged after trimming, so trailing whitespace never costs the
        // user their reflection, and rejected rather than truncated.
        let trimmedJournal = journal?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedJournal, trimmedJournal.count > Constants.maxJournalLength {
            throw ChallengeServiceError.journalTooLong(
                limit: Constants.maxJournalLength,
                actual: trimmedJournal.count
            )
        }
        let finalJournal = trimmedJournal.flatMap { $0.isEmpty ? nil : $0 }
```

with:

```swift
        // One rule, shared with the edit path — see JournalText.
        let finalJournal: String?
        do {
            finalJournal = try JournalText.validated(journal)
        } catch JournalValidationError.tooLong(let limit, let actual) {
            throw ChallengeServiceError.journalTooLong(limit: limit, actual: actual)
        }
```

- [ ] **Step 6: Verify the existing journal tests still pass**

```bash
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyTests/ChallengeServiceJournalTests \
  -only-testing:FaithfullyTests/JournalTextTests test
```

Expected: PASS. `ChallengeServiceJournalTests` covers 1,999 / 2,000 / 2,001 and the no-truncation guard; it must stay green with zero edits, which is what proves the refactor is behaviour-preserving.

- [ ] **Step 7: Lint and commit**

```bash
make lint
git add Faithfully/Utilities/JournalText.swift Faithfully/Services/ChallengeService.swift \
        FaithfullyTests/JournalTextTests.swift Faithfully.xcodeproj
git commit -m "feat: extract the journal length rule into JournalText

Editing needs the same rule completion uses. Two copies of a length check is
how the truncation bug returns on a new path while the old one stays fixed.

ChallengeServiceJournalTests passes unedited, which is what shows the refactor
preserved behaviour."
```

---

### Task 2: Service method to update a journal entry

**Files:**
- Create: `Faithfully/Models/Results/JournalEditResult.swift`
- Modify: `Faithfully/Services/ChallengeService.swift`
- Test: `FaithfullyTests/JournalEditTests.swift`

**Interfaces:**
- Consumes: `JournalText.validated(_:)`, `PersistenceCoordinating`, `CompletedChallenge`
- Produces:
  - `enum JournalEditFailure: Error, Equatable { case tooLong(limit: Int, actual: Int), entryNotFound, couldNotSave }` with `var message: String`
  - `enum JournalEditResult: Equatable { case saved, failed(JournalEditFailure) }` with `var isSaved: Bool`
  - `ChallengeServiceProtocol.updateJournal(entryID: UUID, to text: String?) -> JournalEditResult`

- [ ] **Step 1: Write the failing test**

Create `FaithfullyTests/JournalEditTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Faithfully

final class JournalEditTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var persistence: InjectablePersistence!
    var badgeService: BadgeService!
    var service: ChallengeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        persistence = InjectablePersistence(context: context)
        badgeService = BadgeService(persistence: persistence)
        service = try ChallengeService(
            persistence: persistence,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: TestHelpers.longEnrolledDate,
            dateProvider: { Date.from(year: 2026, month: 6, day: 15) }
        )
    }

    /// Returns the id of a completion created with the given journal text.
    @discardableResult
    private func makeCompletion(journal: String?) throws -> UUID {
        let day = Date.from(year: 2026, month: 6, day: 15)
        _ = try service.completeChallenge(service.challengeForDate(day), on: day, journal: journal)
        return try XCTUnwrap(context.fetch(FetchDescriptor<CompletedChallenge>()).first).id
    }

    private func storedJournal() throws -> String? {
        try XCTUnwrap(context.fetch(FetchDescriptor<CompletedChallenge>()).first).journalEntry
    }

    private func text(ofLength length: Int) -> String {
        String(repeating: "a", count: length)
    }

    func testEditingReplacesTheText() throws {
        let id = try makeCompletion(journal: "first thoughts")

        XCTAssertEqual(service.updateJournal(entryID: id, to: "second thoughts"), .saved)
        XCTAssertEqual(try storedJournal(), "second thoughts")
    }

    func testClearingSetsTheJournalToNilNotEmptyString() throws {
        let id = try makeCompletion(journal: "regret this")

        XCTAssertEqual(service.updateJournal(entryID: id, to: nil), .saved)
        XCTAssertNil(try storedJournal(),
                     "An empty string would still render as an entry with blank text")
    }

    func testWhitespaceOnlyTextClearsTheEntry() throws {
        let id = try makeCompletion(journal: "regret this")

        XCTAssertEqual(service.updateJournal(entryID: id, to: "   \n  "), .saved)
        XCTAssertNil(try storedJournal())
    }

    func testAddingTextToACompletionThatHadNone() throws {
        let id = try makeCompletion(journal: nil)
        XCTAssertNil(try storedJournal())

        XCTAssertEqual(service.updateJournal(entryID: id, to: "added later"), .saved)
        XCTAssertEqual(try storedJournal(), "added later")
    }

    func testTextAtTheLimitIsAccepted() throws {
        let id = try makeCompletion(journal: "short")
        let atLimit = text(ofLength: Constants.maxJournalLength)

        XCTAssertEqual(service.updateJournal(entryID: id, to: atLimit), .saved)
        XCTAssertEqual(try storedJournal()?.count, Constants.maxJournalLength)
    }

    func testTextOverTheLimitIsRejectedAndNothingChanges() throws {
        let id = try makeCompletion(journal: "keep me")
        let over = text(ofLength: Constants.maxJournalLength + 1)

        XCTAssertEqual(
            service.updateJournal(entryID: id, to: over),
            .failed(.tooLong(limit: Constants.maxJournalLength,
                             actual: Constants.maxJournalLength + 1))
        )
        XCTAssertEqual(try storedJournal(), "keep me",
                       "A rejected edit must not damage the text it was editing")
    }

    func testUnknownEntryReportsNotFoundAndWritesNothing() throws {
        try makeCompletion(journal: "untouched")

        XCTAssertEqual(service.updateJournal(entryID: UUID(), to: "nope"), .failed(.entryNotFound))
        XCTAssertEqual(try storedJournal(), "untouched")
    }

    func testFailedSaveRollsBackAndKeepsTheOriginalText() throws {
        let id = try makeCompletion(journal: "original")
        persistence.failNextSave = true

        XCTAssertEqual(service.updateJournal(entryID: id, to: "replacement"), .failed(.couldNotSave))
        XCTAssertEqual(persistence.rollbackCount, 1)
        XCTAssertEqual(try storedJournal(), "original",
                       "A failed save must leave the stored reflection untouched")
    }

    // MARK: - The invariant this whole feature rests on

    func testEditingDoesNotMoveStreakTotalOrBadges() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        // 31 consecutive days earns the 5K journey badge.
        for offset in 0..<31 {
            let date = today.addingDays(-offset)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay,
                journalEntry: offset == 0 ? "the entry we will edit" : nil
            ))
        }
        try context.save()
        try persistence.transaction { _ = badgeService.evaluateAndStageAwards() }

        let streakBefore = service.calculateStreak()
        let totalBefore = service.fetchAllCompletions().count
        let badgesBefore = Set(badgeService.earnedBadges().map(\.badgeName))
        XCTAssertGreaterThan(streakBefore, 0)
        XCTAssertTrue(badgesBefore.contains("journey_5k"), "Precondition: a badge is earned")

        let target = try XCTUnwrap(
            context.fetch(FetchDescriptor<CompletedChallenge>())
                .first { $0.journalEntry != nil }
        )
        XCTAssertEqual(service.updateJournal(entryID: target.id, to: "edited"), .saved)
        XCTAssertEqual(service.updateJournal(entryID: target.id, to: nil), .saved)

        XCTAssertEqual(service.calculateStreak(), streakBefore, "Streak must not move")
        XCTAssertEqual(service.fetchAllCompletions().count, totalBefore, "Total must not move")
        XCTAssertEqual(Set(badgeService.earnedBadges().map(\.badgeName)), badgesBefore,
                       "Badges must not move")
        XCTAssertTrue(service.isCompleted(on: today), "The day must still be completed")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
make generate
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyTests/JournalEditTests test
```

Expected: FAIL — `value of type 'ChallengeService' has no member 'updateJournal'`.

- [ ] **Step 3: Create the result types**

Create `Faithfully/Models/Results/JournalEditResult.swift`:

```swift
import Foundation

/// Why a journal edit could not be saved.
///
/// Deliberately not `CompletionFailure`. Its `.beforeEnrollment`,
/// `.gracePeriodExpired` and `.alreadyCompleted` cases cannot occur for an edit,
/// and a type whose cases cannot occur is a type that lies about its contract.
enum JournalEditFailure: Error, Equatable {
    case tooLong(limit: Int, actual: Int)
    case entryNotFound
    case couldNotSave

    var message: String {
        switch self {
        case .tooLong(let limit, let actual):
            let over = actual - limit
            return "Your reflection is \(over) character\(over == 1 ? "" : "s") over the "
                + "\(limit)-character limit. Shorten it and try again — nothing has changed yet."
        case .entryNotFound:
            return "That day's record couldn't be found, so nothing was changed."
        case .couldNotSave:
            return "That change couldn't be saved. Your reflection is unchanged — please try again."
        }
    }
}

/// The outcome of editing or clearing a reflection.
///
/// Callers must not dismiss the editor until they have seen `.saved`; anything
/// else means the user's text exists only in the sheet they are looking at.
enum JournalEditResult: Equatable {
    case saved
    case failed(JournalEditFailure)

    var isSaved: Bool { self == .saved }
}
```

- [ ] **Step 4: Add the protocol requirement and implementation**

In `Faithfully/Services/ChallengeService.swift`, add to `ChallengeServiceProtocol` immediately after `completeChallenge`:

```swift
    /// Replaces the reflection on an existing completion. `nil` clears it.
    ///
    /// Only `journalEntry` changes: the day, the challenge and the completion
    /// timestamp are untouched, so streak, totals and badges cannot move.
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult
```

Add to `final class ChallengeService`, immediately after `completeChallenge`:

```swift
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult {
        let validated: String?
        do {
            validated = try JournalText.validated(text)
        } catch JournalValidationError.tooLong(let limit, let actual) {
            return .failed(.tooLong(limit: limit, actual: actual))
        } catch {
            return .failed(.couldNotSave)
        }

        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.id == entryID }
        )
        guard let entry = (try? persistence.fetch(descriptor))?.first else {
            return .failed(.entryNotFound)
        }

        // Captured before mutating: `transaction` rolls the context back on
        // failure, but restoring the in-memory object explicitly means the
        // caller never sees a half-applied edit either way.
        let previous = entry.journalEntry
        do {
            try persistence.transaction { entry.journalEntry = validated }
            return .saved
        } catch {
            entry.journalEntry = previous
            return .failed(.couldNotSave)
        }
    }
```

- [ ] **Step 5: Conform the test stub**

In `FaithfullyTests/DailyWalkViewModelTests.swift`, add to `StubChallengeService`, immediately after `func calculateStreak() -> Int { 0 }`:

```swift
        func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult { .saved }
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyTests test
```

Expected: PASS, all tests including the 9 new `JournalEditTests`.

- [ ] **Step 7: Lint and commit**

```bash
make lint
git add Faithfully/Models/Results/JournalEditResult.swift Faithfully/Services/ChallengeService.swift \
        FaithfullyTests/JournalEditTests.swift FaithfullyTests/DailyWalkViewModelTests.swift \
        Faithfully.xcodeproj
git commit -m "feat: add updateJournal to the challenge service

Writes only journalEntry, inside a transaction, so streak, totals and badges
cannot move. The invariant has a test rather than a comment.

A rejected or failed edit leaves the stored reflection exactly as it was."
```

---

### Task 3: Extract the shared editor

**Files:**
- Create: `Faithfully/Views/Shared/JournalEditorView.swift`
- Modify: `Faithfully/Views/DailyWalk/CompletionSheetView.swift`

**Interfaces:**
- Consumes: `Constants.maxJournalLength`
- Produces: `JournalEditorView(text: Binding<String>, errorMessage: String?)`, plus `JournalEditorView.isOverLimit(_ text: String) -> Bool` for callers that need to disable their own submit button.

- [ ] **Step 1: Create the shared editor**

Create `Faithfully/Views/Shared/JournalEditorView.swift`. This is the body lifted verbatim from `CompletionSheetView` — the counter, the over-limit stroke, the accessible label, and the error line. Do not re-derive it; every detail here was a fix.

```swift
import SwiftUI

/// The reflection editor, shared by the completion sheet and the edit sheet.
///
/// Extracted rather than copied. The live counter, the over-limit block, the
/// accessible label on the `TextEditor` and the failure line that keeps the
/// draft are the combined output of CLEAN-003 and OPS-004; a second copy would
/// rot independently of this one.
struct JournalEditorView: View {
    @Binding var text: String
    /// Set by the caller when a save failed. Shown next to the counter; the
    /// caller keeps the sheet open and the draft intact.
    var errorMessage: String?

    /// Callers disable their own submit button with this, so the rule that
    /// blocks over-limit text lives with the editor that enforces it.
    static func isOverLimit(_ text: String) -> Bool {
        text.count > Constants.maxJournalLength
    }

    private var characterCount: Int { text.count }
    private var isOverLimit: Bool { Self.isOverLimit(text) }

    /// Spoken as a sentence rather than "1998/2000", which VoiceOver reads as a
    /// date.
    private var counterAccessibilityLabel: String {
        if isOverLimit {
            let over = characterCount - Constants.maxJournalLength
            return "\(over) character\(over == 1 ? "" : "s") over the limit"
        }
        let remaining = Constants.maxJournalLength - characterCount
        return "\(remaining) character\(remaining == 1 ? "" : "s") remaining"
    }

    var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $text)
                // A TextEditor has no implicit label, so VoiceOver announced it
                // as an unnamed text field.
                .accessibilityLabel("Your reflection")
                .accessibilityHint("Optional. Up to \(Constants.maxJournalLength) characters.")
                .frame(minHeight: 120)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isOverLimit ? Color.red : Color.gray.opacity(0.3))
                )
                .accessibilityIdentifier("journalEditor")

            HStack {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("completionError")
                }
                Spacer()
                Text("\(characterCount)/\(Constants.maxJournalLength)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(isOverLimit ? .red : Color.supportingText)
                    .accessibilityIdentifier("journalCharacterCount")
                    .accessibilityLabel(counterAccessibilityLabel)
                    .accessibilityValue("\(characterCount) of \(Constants.maxJournalLength)")
            }
        }
    }
}
```

- [ ] **Step 2: Rewrite CompletionSheetView to use it**

Replace the whole of `Faithfully/Views/DailyWalk/CompletionSheetView.swift` with:

```swift
import SwiftUI

struct CompletionSheetView: View {
    @Binding var journalText: String
    /// Set by the caller when a completion attempt failed. The sheet stays open
    /// and the draft stays intact whenever this is non-nil.
    var errorMessage: String?
    let onComplete: () -> Void

    private var isOverLimit: Bool { JournalEditorView.isOverLimit(journalText) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How did it go?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                Text("A short reflection, if you like")
                    .font(.subheadline)
                    // Full label colour: the sheet's background defeated every
                    // reduced-opacity variant in the accessibility audit.
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                JournalEditorView(text: $journalText, errorMessage: errorMessage)

                Button(action: onComplete) {
                    Text("Complete Challenge")
                        .font(.headline)
                        // Clipped at large Dynamic Type sizes before this.
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isOverLimit ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                // Blocked at the source: the user can never submit text that
                // would be rejected after the fact.
                .disabled(isOverLimit)
                .accessibilityIdentifier("completeButton")
                .accessibilityHint(isOverLimit
                    ? "Unavailable until your reflection is within the character limit"
                    : "")

                Spacer()
            }
            .padding()
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        // An explicit background rather than the default material. A material
        // blends whatever is behind the sheet, so text contrast depended on the
        // screen underneath — it passed locally and failed in CI for that reason.
        .presentationBackground(Color(.systemBackground))
    }
}
```

- [ ] **Step 3: Verify the completion flow is unchanged**

```bash
make generate
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyUITests/HomeScreenUITests \
  -only-testing:FaithfullyUITests/AccessibilityAuditTests/testCompletionSheetIsAccessible test
```

Expected: PASS. `testJournalCounterReflectsWhatWasTyped` asserts the counter label exactly, so an extraction that changed the accessible text fails here.

- [ ] **Step 4: Lint and commit**

```bash
make lint
git add Faithfully/Views/Shared/JournalEditorView.swift \
        Faithfully/Views/DailyWalk/CompletionSheetView.swift Faithfully.xcodeproj
git commit -m "refactor: share the reflection editor between both sheets

The counter, over-limit block, accessible label and error line are the output of
CLEAN-003 and OPS-004. The edit sheet needs all of them; a copy would rot
independently.

HomeScreenUITests and the completion-sheet accessibility audit pass unedited."
```

---

### Task 4: Address a journal entry from the calendar

`CalendarDay` carries the journal *text* but not the completion's id, so day detail cannot say which entry to edit.

**Files:**
- Modify: `Faithfully/Models/Results/CalendarDay.swift`
- Modify: `Faithfully/ViewModels/CalendarViewModel.swift`
- Test: `FaithfullyTests/CalendarViewModelTests.swift`

**Interfaces:**
- Consumes: `CompletedChallenge.id`, `ChallengeServiceProtocol.updateJournal(entryID:to:)`
- Produces:
  - `CalendarDay.completionID: UUID?` — non-nil exactly when the day has a completion
  - `CalendarViewModel.updateJournal(entryID: UUID, to text: String?) -> JournalEditResult`

- [ ] **Step 1: Write the failing test**

Append inside `final class CalendarViewModelTests`, before its closing brace:

```swift
    // MARK: - Addressing an entry for editing

    func testCompletedDayCarriesItsCompletionIdentifier() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: "wrote this")

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day15 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })

        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<CompletedChallenge>()).first)
        XCTAssertEqual(day15.completionID, stored.id,
                       "Day detail cannot edit an entry it cannot name")
    }

    func testCompletedDayWithNoReflectionStillCarriesItsIdentifier() throws {
        // This is how "add a reflection later" is possible at all.
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: nil)

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day15 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })

        XCTAssertNil(day15.journalEntry)
        XCTAssertNotNil(day15.completionID)
    }

    func testUncompletedDayHasNoCompletionIdentifier() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day15 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })
        XCTAssertNil(day15.completionID)
    }

    func testUpdatingAJournalRefreshesTheGrid() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: "before")

        let vm = CalendarViewModel(challengeService: service, today: today)
        let id = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }?.completionID)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "after"), .saved)

        let refreshed = vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }
        XCTAssertEqual(refreshed?.journalEntry, "after",
                       "The grid must reflect the edit without a relaunch")
    }

    func testClearingAJournalKeepsTheDayCompleted() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: "gone soon")

        let vm = CalendarViewModel(challengeService: service, today: today)
        let id = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }?.completionID)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: nil), .saved)

        let refreshed = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })
        XCTAssertNil(refreshed.journalEntry)
        XCTAssertEqual(refreshed.status, .completed,
                       "Clearing a reflection must not un-complete the day")
        XCTAssertEqual(refreshed.status.accessibilityDescription, "Completed")
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyTests/CalendarViewModelTests test
```

Expected: FAIL — `value of type 'CalendarDay' has no member 'completionID'`.

- [ ] **Step 3: Add `completionID` to CalendarDay**

In `Faithfully/Models/Results/CalendarDay.swift`, replace the `struct CalendarDay` declaration and initialiser:

```swift
struct CalendarDay: Identifiable, Equatable {
    let id: Date
    let date: Date
    let challenge: DailyChallenge?
    let status: CalendarDayStatus
    let journalEntry: String?
    /// The completion this day corresponds to, when there is one. Non-nil for
    /// every completed day, including days completed without a reflection —
    /// which is what makes adding one later possible.
    let completionID: UUID?

    init(
        date: Date,
        challenge: DailyChallenge? = nil,
        status: CalendarDayStatus,
        journalEntry: String? = nil,
        completionID: UUID? = nil
    ) {
        self.id = date
        self.date = date
        self.challenge = challenge
        self.status = status
        self.journalEntry = journalEntry
        self.completionID = completionID
    }

    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.date == rhs.date
            && lhs.status == rhs.status
            && lhs.journalEntry == rhs.journalEntry
    }
}
```

Note the `==` now includes `journalEntry`. Without it, SwiftUI would not re-render a day whose only change was its reflection.

- [ ] **Step 4: Populate it in CalendarViewModel**

In `loadMonth()`, alongside the existing `journalByDay` dictionary, add an id lookup. Replace:

```swift
        let completedDays = Set(completions.map(\.dayKey))
        let journalByDay = Dictionary(
            completions.compactMap { completion in
                completion.journalEntry.map { (completion.dayKey, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
```

with:

```swift
        let completedDays = Set(completions.map(\.dayKey))
        let journalByDay = Dictionary(
            completions.compactMap { completion in
                completion.journalEntry.map { (completion.dayKey, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        // Keyed for every completion, not only those with text: a day completed
        // without a reflection still needs to be addressable so one can be added.
        let completionIDByDay = Dictionary(
            completions.map { ($0.dayKey, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )
```

Then in the `CalendarDay(...)` construction at the end of `loadMonth()`, add the argument:

```swift
            return CalendarDay(
                date: date,
                challenge: challenge,
                status: status,
                journalEntry: journalByDay[dayKey],
                completionID: completionIDByDay[dayKey]
            )
```

- [ ] **Step 5: Add the view-model method**

Add to `CalendarViewModel`, immediately after `completeGracePeriod`:

```swift
    /// Edits or clears the reflection on a day, then rebuilds the grid.
    ///
    /// Returns the result rather than swallowing it: the caller owns the editor
    /// and the user's text, and must keep both unless this says `.saved`.
    @discardableResult
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult {
        let result = challengeService.updateJournal(entryID: entryID, to: text)
        guard result.isSaved else { return result }

        loadMonth()
        // Re-bind any open detail panel to the rebuilt day, so it shows the new
        // text rather than the value it was constructed with.
        if let selected = selectedDay {
            selectedDay = calendarDays.first {
                Calendar.current.isDate($0.date, inSameDayAs: selected.date)
            }
        }
        return result
    }
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" -only-testing:FaithfullyTests test
```

Expected: PASS.

- [ ] **Step 7: Lint and commit**

```bash
make lint
git add Faithfully/Models/Results/CalendarDay.swift Faithfully/ViewModels/CalendarViewModel.swift \
        FaithfullyTests/CalendarViewModelTests.swift Faithfully.xcodeproj
git commit -m "feat: let the calendar address a day's journal entry

CalendarDay carried the reflection text but not the completion id, so day detail
could not name the entry it wanted to edit. Populated for every completed day,
including those with no reflection — that is what makes adding one later work.

CalendarDay equality now includes journalEntry, or SwiftUI would not re-render a
day whose only change was its text."
```

---

### Task 5: Journey view model edit and delete

**Files:**
- Modify: `Faithfully/ViewModels/JourneyViewModel.swift`
- Test: `FaithfullyTests/JourneyViewModelTests.swift`

**Interfaces:**
- Consumes: `ChallengeServiceProtocol.updateJournal(entryID:to:)`
- Produces: `JourneyViewModel.updateJournal(entryID: UUID, to text: String?) -> JournalEditResult`, and `JourneyViewModel.activeSearchQuery: String` (private set)

- [ ] **Step 1: Write the failing test**

Append inside `final class JourneyViewModelTests`, before its closing brace:

```swift
    // MARK: - Editing and clearing entries

    private func seedEntry(on date: Date, journal: String) throws -> UUID {
        let challenge = challengeService.challengeForDate(date)
        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: date,
            scheduledDate: date.startOfDay,
            journalEntry: journal
        )
        context.insert(completion)
        try context.save()
        return completion.id
    }

    func testEditingAnEntryUpdatesItsTextInPlace() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "before")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.journalEntries.first?.journalText, "before")

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "after"), .saved)

        XCTAssertEqual(vm.journalEntries.count, 1)
        XCTAssertEqual(vm.journalEntries.first?.journalText, "after")
    }

    func testClearingAnEntryRemovesItFromTheTimelineButNotTheTotal() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "regret this")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        let totalBefore = vm.totalCompleted

        XCTAssertEqual(vm.updateJournal(entryID: id, to: nil), .saved)

        XCTAssertTrue(vm.journalEntries.isEmpty, "A cleared entry has nothing to show")
        XCTAssertEqual(vm.totalCompleted, totalBefore,
                       "The day is still completed; only the reflection went")
    }

    func testEditingKeepsTimelineOrdering() throws {
        // Ordering is by completedDate, which an edit does not change.
        _ = try seedEntry(on: Date.from(year: 2026, month: 6, day: 10), journal: "older")
        let newerID = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "newer")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.journalEntries.map(\.journalText), ["newer", "older"])

        XCTAssertEqual(vm.updateJournal(entryID: newerID, to: "newer, revised"), .saved)

        XCTAssertEqual(vm.journalEntries.map(\.journalText), ["newer, revised", "older"])
    }

    func testAnActiveSearchSurvivesAnEdit() throws {
        _ = try seedEntry(on: Date.from(year: 2026, month: 6, day: 10), journal: "apples")
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "apples and pears")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)

        vm.searchJournal("pears")
        XCTAssertEqual(vm.journalEntries.count, 1)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "apples and pears, revised"), .saved)

        XCTAssertEqual(vm.journalEntries.count, 1,
                       "An edit must not silently drop the user back to the unfiltered list")
        XCTAssertEqual(vm.journalEntries.first?.journalText, "apples and pears, revised")
    }

    func testEditingOutOfTheActiveSearchRemovesItFromTheFilteredList() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "apples and pears")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        vm.searchJournal("pears")
        XCTAssertEqual(vm.journalEntries.count, 1)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "apples only"), .saved)

        XCTAssertTrue(vm.journalEntries.isEmpty,
                      "The entry no longer matches the query the user is looking at")
    }

    func testAFailedEditLeavesTheTimelineAlone() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "keep me")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        let over = String(repeating: "a", count: Constants.maxJournalLength + 1)

        XCTAssertEqual(
            vm.updateJournal(entryID: id, to: over),
            .failed(.tooLong(limit: Constants.maxJournalLength,
                             actual: Constants.maxJournalLength + 1))
        )
        XCTAssertEqual(vm.journalEntries.first?.journalText, "keep me")
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyTests/JourneyViewModelTests test
```

Expected: FAIL — `value of type 'JourneyViewModel' has no member 'updateJournal'`.

- [ ] **Step 3: Track the active query and add the method**

In `Faithfully/ViewModels/JourneyViewModel.swift`, add a stored property just below `var journalEntries: [JournalDisplayItem] = []`:

```swift
    /// The query currently filtering the timeline, so a refresh after an edit
    /// re-applies it instead of dropping the user back to the unfiltered list.
    private(set) var activeSearchQuery: String = ""
```

Replace `searchJournal(_:)` with:

```swift
    func searchJournal(_ query: String) {
        activeSearchQuery = query
        guard !query.isEmpty else {
            refresh()
            return
        }
        journalEntries = journalItems(from: allCompletions(), matching: query)
    }
```

`refresh()` must clear the query when called directly, so add this as its final line, replacing `journalEntries = journalItems(from: completions)`:

```swift
        // Journal entries — reverse chronological, honouring any active filter.
        journalEntries = journalItems(
            from: completions,
            matching: activeSearchQuery.isEmpty ? nil : activeSearchQuery
        )
```

Add the edit method, immediately after `searchJournal`:

```swift
    /// Edits or clears a reflection, then rebuilds the timeline.
    ///
    /// Returns the result rather than swallowing it: the caller owns the editor
    /// and the user's text, and must keep both unless this says `.saved`.
    @discardableResult
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult {
        let result = challengeService.updateJournal(entryID: entryID, to: text)
        guard result.isSaved else { return result }
        refresh()
        return result
    }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" -only-testing:FaithfullyTests test
```

Expected: PASS. `testSearchFieldFiltersEntries` in the UI suite depends on search still working; that runs in Task 8.

- [ ] **Step 5: Lint and commit**

```bash
make lint
git add Faithfully/ViewModels/JourneyViewModel.swift FaithfullyTests/JourneyViewModelTests.swift
git commit -m "feat: edit and clear reflections from the Journey timeline

Refresh now honours the active search query. Without that, editing an entry
while a filter was applied silently dropped the user back to the unfiltered
list — a jarring result for an action that should be local."
```

---

### Task 6: Journey UI — tap to edit, button to delete

**Files:**
- Create: `Faithfully/Views/Shared/JournalEditSheet.swift`
- Modify: `Faithfully/Views/Journey/JourneyView.swift`

**Interfaces:**
- Consumes: `JournalEditorView`, `JournalEditResult`, `JourneyViewModel.updateJournal(entryID:to:)`
- Produces: `JournalEditSheet(title:date:originalText:onSave:onCancel:)` where `onSave: (String?) -> JournalEditResult`

- [ ] **Step 1: Create the edit sheet**

Create `Faithfully/Views/Shared/JournalEditSheet.swift`:

```swift
import SwiftUI

/// Edits the reflection on one completed day.
///
/// Saving is a closure returning a result rather than a plain callback, for the
/// same reason completion is: the sheet must not dismiss or discard the draft
/// until it knows the write landed.
struct JournalEditSheet: View {
    let title: String
    let date: Date
    let originalText: String?
    let onSave: (String?) -> JournalEditResult
    let onCancel: () -> Void

    @State private var text: String
    @State private var errorMessage: String?
    @State private var confirmingClear = false

    init(
        title: String,
        date: Date,
        originalText: String?,
        onSave: @escaping (String?) -> JournalEditResult,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.date = date
        self.originalText = originalText
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: originalText ?? "")
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Saving empty text over existing text destroys writing just as thoroughly
    /// as swiping to delete, so it takes the same confirmation.
    private var wouldClearExistingText: Bool {
        trimmed.isEmpty && !(originalText ?? "").isEmpty
    }

    private var isOverLimit: Bool { JournalEditorView.isOverLimit(text) }

    private var formattedDate: String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .frame(maxWidth: .infinity)

                JournalEditorView(text: $text, errorMessage: errorMessage)

                Button(action: attemptSave) {
                    Text("Save")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isOverLimit ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isOverLimit)
                .accessibilityIdentifier("saveJournalButton")

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancelJournalEdit")
                }
            }
        }
        .presentationDetents([.medium])
        // Explicit, not a material: contrast measured against a blurred backdrop
        // depends on whatever the user was looking at a moment ago.
        .presentationBackground(Color(.systemBackground))
        .confirmationDialog(
            "Delete this reflection?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { commit(nil) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your reflection for \(formattedDate) will be permanently deleted. "
                 + "The day stays completed — your streak and badges aren't affected.")
        }
    }

    private func attemptSave() {
        if wouldClearExistingText {
            confirmingClear = true
        } else {
            commit(trimmed.isEmpty ? nil : text)
        }
    }

    private func commit(_ value: String?) {
        switch onSave(value) {
        case .saved:
            errorMessage = nil
            onCancel()
        case .failed(let failure):
            // Sheet stays open, draft intact.
            errorMessage = failure.message
        }
    }
}
```

- [ ] **Step 2: Wire it into JourneyView**

In `Faithfully/Views/Journey/JourneyView.swift`, add state below `@State private var searchText = ""`:

```swift
    @State private var editingEntry: JournalDisplayItem?
    @State private var pendingDeletion: JournalDisplayItem?
```

Replace the journal entry row block. The existing `ForEach(vm.journalEntries) { entry in ... }` body keeps its content; add the tap target, the delete button and the identifiers. Replace:

```swift
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityIdentifier("journalEntry_\(entry.id)")
```

with:

```swift
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityIdentifier("journalEntry_\(entry.id)")
                                .contentShape(Rectangle())
                                .onTapGesture { editingEntry = entry }
                                .accessibilityHint("Double tap to edit this reflection")
                                .accessibilityAction(named: "Edit") { editingEntry = entry }
                                .accessibilityAction(named: "Delete") { pendingDeletion = entry }
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        pendingDeletion = entry
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.footnote)
                                            .foregroundStyle(Color.supportingText)
                                            // 44pt tappable area, not 13pt of ink.
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .accessibilityIdentifier("deleteJournalEntry_\(entry.id)")
                                    .accessibilityLabel("Delete reflection")
                                }
```

Add the sheet and dialog modifiers to the `ScrollView`, immediately after `.navigationTitle("My Journey")`:

```swift
            .sheet(item: $editingEntry) { entry in
                JournalEditSheet(
                    title: "Edit reflection",
                    date: entry.date,
                    originalText: entry.journalText,
                    onSave: { vm.updateJournal(entryID: entry.id, to: $0) },
                    onCancel: { editingEntry = nil }
                )
            }
            .confirmationDialog(
                "Delete this reflection?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = pendingDeletion {
                        _ = vm.updateJournal(entryID: entry.id, to: nil)
                    }
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("Your reflection will be permanently deleted. The day stays completed — "
                     + "your streak and badges aren't affected.")
            }
```

`JournalDisplayItem` is already `Identifiable`, so `.sheet(item:)` works unchanged.

- [ ] **Step 3: Build and run the existing Journey UI tests**

```bash
make generate
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyUITests/JourneyUITests test
```

Expected: PASS. The existing search and badge tests must be unaffected by the new row affordances.

- [ ] **Step 4: Lint and commit**

```bash
make lint
git add Faithfully/Views/Shared/JournalEditSheet.swift Faithfully/Views/Journey/JourneyView.swift \
        Faithfully.xcodeproj
git commit -m "feat: edit and delete reflections from the Journey timeline

Delete is confirmed and the dialog says the day stays completed, because the
streak is what people actually fear losing.

Clearing the text in the editor and saving takes the same confirmation: it
destroys writing just as thoroughly, so it cannot be the path that skips the
guard."
```

---

### Task 7: Calendar UI — edit and add

**Files:**
- Modify: `Faithfully/Views/Calendar/DayDetailView.swift`
- Modify: `Faithfully/Views/Calendar/CalendarScreenView.swift`

**Interfaces:**
- Consumes: `CalendarDay.completionID`, `JournalEditSheet`, `CalendarViewModel.updateJournal(entryID:to:)`
- Produces: `DayDetailView(day:onComplete:onEditJournal:)`

- [ ] **Step 1: Add the affordance to DayDetailView**

In `Faithfully/Views/Calendar/DayDetailView.swift`, add a property below `let onComplete: () -> Void`:

```swift
    /// Called with the day's completion id when the user wants to write or
    /// change its reflection.
    let onEditJournal: (UUID) -> Void
```

Replace the journal display block:

```swift
                if let journal = day.journalEntry {
                    Text("Journal: \(journal)")
                        .font(.callout)
                        .foregroundStyle(Color.supportingText)
                        .italic()
                }
```

with:

```swift
                if let journal = day.journalEntry {
                    Text("Journal: \(journal)")
                        .font(.callout)
                        .foregroundStyle(Color.supportingText)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Reachable for every completed day, including one with no
                // reflection — this is the only route back to a day whose text
                // was cleared from the Journey timeline.
                if let completionID = day.completionID {
                    Button(day.journalEntry == nil ? "Add reflection" : "Edit reflection") {
                        onEditJournal(completionID)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editJournalButton")
                }
```

- [ ] **Step 2: Present the sheet from CalendarScreenView**

In `Faithfully/Views/Calendar/CalendarScreenView.swift`, add state below `let vm: CalendarViewModel`:

```swift
    @State private var editingEntry: EditingEntry?

    /// Identifies which day's reflection the sheet is editing.
    private struct EditingEntry: Identifiable {
        let id: UUID
        let date: Date
        let text: String?
    }
```

Replace the day-detail block:

```swift
                    if let selected = vm.selectedDay {
                        DayDetailView(day: selected) {
                            vm.completeGracePeriod(selected)
                            vm.selectedDay = nil
                        }
                    }
```

with:

```swift
                    if let selected = vm.selectedDay {
                        DayDetailView(
                            day: selected,
                            onComplete: {
                                vm.completeGracePeriod(selected)
                                vm.selectedDay = nil
                            },
                            onEditJournal: { id in
                                editingEntry = EditingEntry(
                                    id: id, date: selected.date, text: selected.journalEntry
                                )
                            }
                        )
                    }
```

Add the sheet to the `ScrollView`, immediately after `.navigationTitle("Calendar")`:

```swift
            .sheet(item: $editingEntry) { entry in
                JournalEditSheet(
                    title: entry.text == nil ? "Add reflection" : "Edit reflection",
                    date: entry.date,
                    originalText: entry.text,
                    onSave: { vm.updateJournal(entryID: entry.id, to: $0) },
                    onCancel: { editingEntry = nil }
                )
            }
```

- [ ] **Step 3: Build and run the calendar UI tests**

```bash
make generate
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyUITests/CalendarUITests test
```

Expected: PASS. The grace-period and pre-enrollment tests exercise `DayDetailView`; its new initialiser parameter must not break them.

- [ ] **Step 4: Lint and commit**

```bash
make lint
git add Faithfully/Views/Calendar/DayDetailView.swift \
        Faithfully/Views/Calendar/CalendarScreenView.swift Faithfully.xcodeproj
git commit -m "feat: edit or add a reflection from the calendar day detail

The only surface that shows every completed day, so it is the only route back to
a day whose reflection was cleared from the Journey timeline. Without it,
clearing an entry would be a one-way door."
```

---

### Task 8: End-to-end UI tests

**Files:**
- Create: `FaithfullyUITests/JournalEditUITests.swift`
- Modify: `FaithfullyUITests/AccessibilityAuditTests.swift`

**Interfaces:**
- Consumes: `UITestCase`, the `seeded` scenario, `UITestSupport.searchableJournalText`

- [ ] **Step 1: Write the UI tests**

Create `FaithfullyUITests/JournalEditUITests.swift`:

```swift
import XCTest

final class JournalEditUITests: UITestCase {

    private let alpha = "seeded-journal-marker-alpha"

    private func journalEntry(containing marker: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
    }

    private func openEditorForFirstEntry() {
        openTab("Journey")
        let entry = journalEntry(containing: alpha)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.textViews["journalEditor"].waitForExistence(timeout: 5),
                      "Tapping an entry must open the editor")
    }

    func testEditingAnEntryPersistsAcrossRelaunch() {
        launch(.seeded)
        openEditorForFirstEntry()

        let editor = app.textViews["journalEditor"]
        editor.tap()
        editor.typeText(" — revised")
        app.buttons["saveJournalButton"].tap()

        let revised = journalEntry(containing: "revised")
        XCTAssertTrue(revised.waitForExistence(timeout: 10),
                      "The edited text must appear in the timeline")

        relaunchPreservingState()
        openTab("Journey")
        XCTAssertTrue(journalEntry(containing: "revised").waitForExistence(timeout: 10),
                      "The edit must survive a relaunch")
    }

    func testCancellingAnEditChangesNothing() {
        launch(.seeded)
        openEditorForFirstEntry()

        let editor = app.textViews["journalEditor"]
        editor.tap()
        editor.typeText(" DISCARD ME")
        app.buttons["cancelJournalEdit"].tap()

        XCTAssertTrue(journalEntry(containing: alpha).waitForExistence(timeout: 10))
        XCTAssertFalse(journalEntry(containing: "DISCARD ME").exists,
                       "Cancelling must not write anything")
    }

    func testDeletingAnEntryAsksFirstAndCanBeCancelled() {
        launch(.seeded)
        openTab("Journey")
        let entry = journalEntry(containing: alpha)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))

        let total = intValue(of: "statTotalCompleted")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deleteJournalEntry_'"))
            .firstMatch.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5),
                      "Deleting must ask before destroying writing")
        app.buttons["Cancel"].tap()

        XCTAssertTrue(journalEntry(containing: alpha).waitForExistence(timeout: 5),
                      "Cancelling the dialog must keep the entry")
        XCTAssertEqual(intValue(of: "statTotalCompleted"), total)
    }

    func testDeletingAnEntryRemovesItButKeepsTheDayCompleted() {
        launch(.seeded)
        openTab("Journey")
        XCTAssertTrue(journalEntry(containing: alpha).waitForExistence(timeout: 10))

        let totalBefore = intValue(of: "statTotalCompleted")
        let streakBefore = intValue(of: "statCurrentStreak")

        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deleteJournalEntry_'"))
            .firstMatch.tap()
        app.buttons["Delete"].tap()

        XCTAssertFalse(journalEntry(containing: alpha).waitForExistence(timeout: 5),
                       "The entry must leave the timeline")
        XCTAssertEqual(intValue(of: "statTotalCompleted"), totalBefore,
                       "Deleting a reflection must not change the completion total")
        XCTAssertEqual(intValue(of: "statCurrentStreak"), streakBefore,
                       "nor the streak")

        relaunchPreservingState()
        openTab("Journey")
        XCTAssertFalse(journalEntry(containing: alpha).waitForExistence(timeout: 5),
                       "The deletion must survive a relaunch")
    }

    func testAddingAReflectionFromTheCalendarToADayThatHadNone() throws {
        try XCTSkipUnless(isInCurrentMonth(daysAgo: 4),
                          "Target day is in the previous month")
        launch(.seeded)
        openTab("Calendar")

        // In the seeded scenario only the two most recent completions carry
        // journal text, so four days ago is completed with none.
        let day = dayButton(dayNumber(daysAgo: 4))
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.tap()
        revealDayDetail()

        let edit = app.buttons["editJournalButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5),
                      "A completed day with no reflection must offer to add one")
        XCTAssertEqual(edit.label, "Add reflection")
        edit.tap()

        let marker = "uitest-added-later"
        let editor = app.textViews["journalEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(marker)
        app.buttons["saveJournalButton"].tap()

        openTab("Journey")
        XCTAssertTrue(journalEntry(containing: marker).waitForExistence(timeout: 10),
                      "A reflection added from the calendar must appear in the journal")
    }

    func testOverLimitTextBlocksSaving() {
        launch(.seeded)
        openEditorForFirstEntry()

        let counter = app.staticTexts["journalCharacterCount"]
        XCTAssertTrue(counter.waitForExistence(timeout: 5))

        // Paste rather than type: 2,001 keystrokes takes minutes.
        let editor = app.textViews["journalEditor"]
        editor.tap()
        UIPasteboard.general.string = String(repeating: "a", count: Constants.maxJournalLengthForUITests + 1)
        editor.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 5) { paste.tap() }

        XCTAssertFalse(app.buttons["saveJournalButton"].isEnabled,
                       "Saving must be blocked while the text is over the limit")
    }
}
```

Note `Constants.maxJournalLengthForUITests`: the UI test target does not import the app module, so add this to the top of the file, outside the class:

```swift
/// Mirrors `Constants.maxJournalLength`. The UI test target cannot import the
/// app module, so the value is restated here; `JournalTextTests` guards the real
/// one.
private extension Constants {
    static let maxJournalLengthForUITests = 2000
}
```

If `Constants` is not visible to the UI test target — it is not, since UI tests run out of process — replace that extension with a file-private constant instead:

```swift
/// Mirrors `Constants.maxJournalLength` (2000). UI tests run out of process and
/// cannot import the app module, so the value is restated. `JournalTextTests`
/// guards the real one.
private let maxJournalLengthForUITests = 2000
```

and use `maxJournalLengthForUITests` in the test body.

- [ ] **Step 2: Add an accessibility audit for the edit sheet**

Append inside `final class AccessibilityAuditTests`, before its closing brace:

```swift
    func testJournalEditSheetIsAccessible() throws {
        launch(.seeded)
        openTab("Journey")
        let entry = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "seeded-journal-marker-alpha"))
            .firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.textViews["journalEditor"].waitForExistence(timeout: 5))
        try audit(app)
    }
```

- [ ] **Step 3: Run the new tests**

```bash
make generate
xcodebuild -project Faithfully.xcodeproj -scheme Faithfully \
  -destination "$(./scripts/resolve_simulator.sh)" \
  -only-testing:FaithfullyUITests/JournalEditUITests \
  -only-testing:FaithfullyUITests/AccessibilityAuditTests/testJournalEditSheetIsAccessible test
```

Expected: PASS. If the audit reports a contrast or hit-area failure on the new sheet, fix the view — do not add an exclusion.

- [ ] **Step 4: Lint and commit**

```bash
make lint
git add FaithfullyUITests/JournalEditUITests.swift FaithfullyUITests/AccessibilityAuditTests.swift \
        Faithfully.xcodeproj
git commit -m "test: end-to-end coverage for editing and deleting reflections

Asserts the invariant through the UI as well as the service: deleting a
reflection leaves the completion total and the streak untouched.

Covers the round trip from the calendar too, which is the only route to a day
that has no reflection yet."
```

---

### Task 9: Update the documents this changes

Three documents currently state that per-entry deletion does not exist. Leaving them is exactly the drift CLEAN-011 fixed.

**Files:**
- Modify: `docs/ship/DATA_PROTECTION.md`
- Modify: `docs/ship/README.md`
- Modify: `docs/ship/CLAIMS.md`

- [ ] **Step 1: Correct the deletion table in DATA_PROTECTION.md**

Replace the row:

```markdown
| Delete a single journal entry | **Not supported.** A completion cannot currently be undone or edited |
```

with:

```markdown
| Edit or delete a single journal entry | Supported, from the Journey timeline or Calendar day detail. Deleting clears the reflection only — the day stays completed and the streak is unaffected |
| Undo a completion | **Not supported.** A completed day cannot be un-completed |
```

Then replace the paragraph immediately below the table:

```markdown
That last row is a real gap for a journal app. Someone who writes something they
regret has no way to remove it short of deleting the app. Worth a product
decision before public release.
```

with:

```markdown
Deleting a reflection is guarded by a confirmation that names the date and states
that the day stays completed — the streak is what people actually fear losing.
Clearing the text in the editor and saving takes the same confirmation, because
it destroys writing just as thoroughly.

There is deliberately no version history. Recording that someone revised a
confession works against the point of letting them revise it.
```

- [ ] **Step 2: Update the status row in docs/ship/README.md**

Replace:

```markdown
| Per-entry journal deletion | 🟡 Not supported | A user cannot remove a single entry; needs a product decision before public release — [DATA_PROTECTION.md](../../ship/DATA_PROTECTION.md) |
```

with:

```markdown
| Journal edit and delete | 🟢 Ready | Edit, clear, or add a reflection from Journey or Calendar; the completion is never touched — [DATA_PROTECTION.md](../../ship/DATA_PROTECTION.md) |
```

- [ ] **Step 3: Add the claim to docs/ship/CLAIMS.md**

Add to the "Claims with automated proof" table, after the row for "A reflection you write is saved whole":

```markdown
| You can change or remove a reflection you wrote | product behaviour | `JournalEditTests`; `JournalEditUITests.testEditingAnEntryPersistsAcrossRelaunch`, `...testDeletingAnEntryRemovesItButKeepsTheDayCompleted` |
| Removing a reflection does not affect your streak or badges | delete confirmation copy | `JournalEditTests.testEditingDoesNotMoveStreakTotalOrBadges` |
```

- [ ] **Step 4: Verify every internal link still resolves**

```bash
python3 - <<'PY'
import re, pathlib
bad = []
for md in pathlib.Path("docs").rglob("*.md"):
    for label, target in re.findall(r"\[([^\]]+)\]\(([^)]+)\)", md.read_text()):
        if target.startswith(("http", "#", "mailto")):
            continue
        t = target.split("#")[0]
        if t and not (md.parent / t).resolve().exists():
            bad.append(f"{md}: {target}")
print("broken links:", bad or "none")
PY
```

Expected: `broken links: none`.

- [ ] **Step 5: Run the full gate**

```bash
make ci
```

Expected: `All checks passed.` This is the merge gate — hosted CI is manual-only.

- [ ] **Step 6: Commit**

```bash
git add docs/
git commit -m "docs: record that reflections can now be edited and deleted

DATA_PROTECTION.md flagged the absence of per-entry deletion as needing a
product decision. It has one, so the row is corrected rather than left to drift,
and CLAIMS.md gains the promise plus the test that holds it."
```

---

## Self-Review

**Spec coverage.** Every section of the design maps to a task: delete-means-text-only (Tasks 2, 4, 5 — with the invariant test in Task 2), two entry points with Calendar canonical (Tasks 6, 7), confirmation on both the delete-button and the clear-via-editor path (Task 6's dialog and `JournalEditSheet.wouldClearExistingText`), shared validation (Task 1), shared editor (Task 3), no time limit (nothing implements a limit), error handling that preserves the draft (Task 2's failure cases plus `JournalEditSheet.commit`), and the full testing list (Tasks 2, 4, 5, 8). The "consequences to record on landing" section is Task 9.

**One addition the spec implied but did not name:** `CalendarDay.completionID`. Day detail cannot edit an entry it cannot address. Task 4 covers it, including the `Equatable` change without which SwiftUI would not re-render an edited day.

**Type consistency.** `updateJournal(entryID:to:)` has the same signature on the protocol, both view models, and the stub. `JournalEditResult` / `JournalEditFailure` are defined once in Task 2 and used unchanged after. `JournalEditorView.isOverLimit(_:)` is defined in Task 3 and used by both sheets. `JournalText.validated(_:)` is defined in Task 1 and used in Tasks 1 and 2. `DayDetailView`'s new `onEditJournal` parameter is added in Task 7 along with its only call site.

**Known risk, called out rather than hidden:** Task 8's over-limit test depends on the simulator's paste menu, which is timing-sensitive. If it proves flaky, the correct fix is to delete that UI test and rely on `JournalEditTests.testTextOverTheLimitIsRejectedAndNothingChanges`, which covers the same rule deterministically — not to add retries.
