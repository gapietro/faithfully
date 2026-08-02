import Foundation
import SwiftData
@testable import Faithfully

enum TestHelpers {
    /// An enrollment date far earlier than any scenario date in these suites.
    /// Tests that are not about the enrollment boundary (CLEAN-002) use it so
    /// they keep exercising the behaviour they were written for, instead of
    /// silently tripping the boundary and passing for the wrong reason.
    static let longEnrolledDate = Date.from(year: 2020, month: 1, day: 1)

    static func makeModelContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedChallenge.self, EarnedBadge.self,
            configurations: config
        )
    }

    static func loadTestChallenges() throws -> [DailyChallenge] {
        try ChallengeLoader.loadChallenges(from: Bundle(for: MarkerClass.self))
    }
}

// Marker class to find the test bundle
private class MarkerClass {}
