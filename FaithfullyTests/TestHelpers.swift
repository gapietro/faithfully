import Foundation
import SwiftData
@testable import Faithfully

enum TestHelpers {
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
