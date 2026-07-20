import XCTest
@testable import Faithfully

final class ChallengeLoaderTests: XCTestCase {

    var challenges: [DailyChallenge]!

    override func setUpWithError() throws {
        challenges = try ChallengeLoader.loadChallenges(from: Bundle(for: type(of: self)))
    }

    func testLoads365ChallengesFromBundledJSON() {
        XCTAssertEqual(challenges.count, 365, "Should load exactly 365 challenges")
    }

    func testAllChallengesHaveNonEmptyRequiredFields() {
        for challenge in challenges {
            XCTAssertFalse(challenge.id.isEmpty, "Challenge ID should not be empty")
            XCTAssertFalse(challenge.title.isEmpty, "Title should not be empty for \(challenge.id)")
            XCTAssertFalse(challenge.scriptureReference.isEmpty, "Scripture reference should not be empty for \(challenge.id)")
            XCTAssertFalse(challenge.scriptureTextWEB.isEmpty, "WEB text should not be empty for \(challenge.id)")
            XCTAssertFalse(challenge.scriptureTextKJV.isEmpty, "KJV text should not be empty for \(challenge.id)")
            XCTAssertFalse(challenge.challengeDescription.isEmpty, "Description should not be empty for \(challenge.id)")
            XCTAssertFalse(challenge.reflectionPrompt.isEmpty, "Reflection prompt should not be empty for \(challenge.id)")
        }
    }

    func testAllChallengeIDsAreUnique() {
        let ids = challenges.map(\.id)
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All challenge IDs should be unique")
    }

    func testAllDays1Through365AreRepresented() {
        let days = Set(challenges.map(\.day))
        for day in 1...365 {
            XCTAssertTrue(days.contains(day), "Day \(day) should be represented")
        }
    }

    func testCategoryEnumMapsCorrectlyForAllChallenges() {
        let validCategories = Set(ChallengeCategory.allCases.map(\.rawValue))
        for challenge in challenges {
            XCTAssertTrue(validCategories.contains(challenge.category.rawValue),
                         "Category '\(challenge.category.rawValue)' should be a valid ChallengeCategory for \(challenge.id)")
        }
    }

    func testDifficultyEnumMapsCorrectly() {
        let validDifficulties = Set(Difficulty.allCases.map(\.rawValue))
        for challenge in challenges {
            XCTAssertTrue(validDifficulties.contains(challenge.difficulty.rawValue),
                         "Difficulty '\(challenge.difficulty.rawValue)' should be valid for \(challenge.id)")
        }
    }

    func testScriptureTextForTranslationReturnsCorrectTranslation() {
        let challenge = challenges.first!

        XCTAssertEqual(challenge.scriptureText(for: .web), challenge.scriptureTextWEB)
        XCTAssertEqual(challenge.scriptureText(for: .kjv), challenge.scriptureTextKJV)
    }

    func testLegacyTranslationRawValuesDecodeAsWEB() throws {
        let decoder = JSONDecoder()
        for legacy in ["\"esv\"", "\"niv\"", "\"nkjv\"", "\"unknown\""] {
            let decoded = try decoder.decode(BibleTranslation.self, from: Data(legacy.utf8))
            XCTAssertEqual(decoded, .web,
                           "Pre-PD raw value \(legacy) must migrate to the WEB default, not crash")
        }
        let kjv = try decoder.decode(BibleTranslation.self, from: Data("\"kjv\"".utf8))
        XCTAssertEqual(kjv, .kjv)
    }
}
