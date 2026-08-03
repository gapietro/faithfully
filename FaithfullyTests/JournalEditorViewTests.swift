import XCTest
@testable import Faithfully

/// Guards `JournalEditorView.isOverLimit` against drifting from
/// `JournalText.validated` again — the editor blocked Save on text the
/// service would happily accept because it counted before trimming.
final class JournalEditorViewTests: XCTestCase {

    private func text(ofLength length: Int) -> String {
        String(repeating: "a", count: length)
    }

    func testTextAtTheLimitIsNotOverLimit() {
        XCTAssertFalse(JournalEditorView.isOverLimit(text(ofLength: Constants.maxJournalLength)))
    }

    func testTextOverTheLimitIsOverLimit() {
        XCTAssertTrue(JournalEditorView.isOverLimit(text(ofLength: Constants.maxJournalLength + 1)))
    }

    func testTrailingNewlineAtTheLimitIsNotOverLimit() {
        // 2,000 characters plus a trailing newline must never cost someone
        // their entry — the validator agrees; the editor must too.
        let padded = text(ofLength: Constants.maxJournalLength) + "\n"
        XCTAssertFalse(JournalEditorView.isOverLimit(padded),
                       "Trailing whitespace must not trip the over-limit check")
    }

    func testTrailingWhitespaceCannotHideARealOverage() {
        let padded = text(ofLength: Constants.maxJournalLength + 1) + "\n   "
        XCTAssertTrue(JournalEditorView.isOverLimit(padded),
                      "Trimming must not let genuinely over-limit text through")
    }
}
