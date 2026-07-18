import Foundation

struct ChallengeLoader {
    enum LoadError: Error {
        case fileNotFound
        case decodingFailed(Error)
    }

    static func loadChallenges(from bundle: Bundle = .main) throws -> [DailyChallenge] {
        guard let url = bundle.url(forResource: "challenges", withExtension: "json") else {
            throw LoadError.fileNotFound
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([DailyChallenge].self, from: data)
        } catch {
            throw LoadError.decodingFailed(error)
        }
    }
}
