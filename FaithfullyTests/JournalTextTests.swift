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
