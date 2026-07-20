import Foundation

struct DailyChallenge: Codable, Identifiable, Equatable {
    let id: String
    let day: Int
    let title: String
    let category: ChallengeCategory
    let scriptureReference: String
    let scriptureTextWEB: String
    let scriptureTextKJV: String
    let challengeDescription: String
    let reflectionPrompt: String
    let difficulty: Difficulty

    func scriptureText(for translation: BibleTranslation) -> String {
        switch translation {
        case .web: return scriptureTextWEB
        case .kjv: return scriptureTextKJV
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, day, title, category, difficulty
        case scriptureReference = "scripture_reference"
        case scriptureTextWEB = "scripture_text_web"
        case scriptureTextKJV = "scripture_text_kjv"
        case challengeDescription = "challenge_description"
        case reflectionPrompt = "reflection_prompt"
    }
}
