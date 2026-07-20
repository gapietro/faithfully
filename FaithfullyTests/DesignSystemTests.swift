import XCTest
@testable import Faithfully

final class DesignSystemTests: XCTestCase {

    // MARK: - Specialty badge names (#10)

    func testPrayerLadderMatchesPRD() {
        let names = BadgeDefinition.categoryBadges(for: .prayer).map(\.name)
        XCTAssertEqual(names, ["Prayer Beginner", "Prayer Devoted", "Prayer Warrior", "Prayer Master"])
    }

    func testScriptureLadderMatchesPRD() {
        let names = BadgeDefinition.categoryBadges(for: .scripture).map(\.name)
        XCTAssertEqual(names, ["Scripture Beginner", "Scripture Scholar", "Scripture Warrior", "Scripture Master"])
    }

    func testEvangelismLadderMatchesPRD() {
        let names = BadgeDefinition.categoryBadges(for: .evangelism).map(\.name)
        XCTAssertEqual(names, ["Witness Beginner", "Witness Devoted", "Gospel Warrior", "Gospel Master"])
    }

    func testGivingLadderMatchesPRD() {
        let names = BadgeDefinition.categoryBadges(for: .giving).map(\.name)
        XCTAssertEqual(names, ["Giver Beginner", "Generous Heart", "Sacrificial Giver", "Cheerful Giver"])
    }

    func testEveryCategoryHasFourTiersAtStandardThresholds() {
        for category in ChallengeCategory.allCases {
            let badges = BadgeDefinition.categoryBadges(for: category)
            XCTAssertEqual(badges.map(\.threshold), [10, 25, 50, 100], "\(category) thresholds")
            XCTAssertEqual(Set(badges.map(\.name)).count, 4, "\(category) names should be distinct")
            for badge in badges {
                XCTAssertFalse(badge.name.isEmpty)
                XCTAssertEqual(badge.type, .category)
                XCTAssertEqual(badge.category, category)
            }
        }
    }

    func testCategoryBadgeIdsRemainStableAfterRename() {
        // Earned badges persist by id; renaming display names must not change ids.
        XCTAssertEqual(
            BadgeDefinition.categoryBadges(for: .scripture).map(\.id),
            ["scripture_beginner", "scripture_devoted", "scripture_warrior", "scripture_master"]
        )
        XCTAssertEqual(
            BadgeDefinition.categoryBadges(for: .spiritualWarfare).map(\.id),
            ["spiritualWarfare_beginner", "spiritualWarfare_devoted", "spiritualWarfare_warrior", "spiritualWarfare_master"]
        )
    }

    func testAllBadgeIdsAreUnique() {
        let ids = BadgeDefinition.allBadges.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEvaluatorReturnsSpecialtyNames() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 100,
            currentStreak: 0,
            categoryCounts: [.giving: 100, .evangelism: 50],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "Cheerful Giver" }))
        XCTAssertTrue(badges.contains(where: { $0.name == "Gospel Warrior" }))
    }

    // MARK: - Category icons (#11)

    func testEveryCategoryHasAnIcon() {
        for category in ChallengeCategory.allCases {
            XCTAssertFalse(category.iconName.isEmpty, "\(category) needs an SF Symbol")
        }
    }

    // MARK: - Journal share text (#11)

    func testShareTextIncludesTitleReferenceJournalAndStreak() {
        let card = ShareCardData(
            title: "Pray for a Neighbor",
            category: .prayer,
            date: Date.from(year: 2026, month: 7, day: 20),
            scriptureReference: "James 5:16",
            journalText: "Prayed for the family next door.",
            streakCount: 12
        )
        let text = card.shareText
        XCTAssertTrue(text.contains("Pray for a Neighbor"))
        XCTAssertTrue(text.contains("James 5:16"))
        XCTAssertTrue(text.contains("Prayed for the family next door."))
        XCTAssertTrue(text.contains("12 day streak"))
    }

    func testShareTextOmitsEmptyJournalBlock() {
        let card = ShareCardData(
            title: "Read Psalm 1",
            category: .scripture,
            date: Date.from(year: 2026, month: 7, day: 20),
            scriptureReference: "Psalm 1:1-3",
            journalText: "",
            streakCount: 3
        )
        XCTAssertFalse(card.shareText.contains("\n\n\n"))
        XCTAssertTrue(card.shareText.contains("3 day streak"))
    }
}
