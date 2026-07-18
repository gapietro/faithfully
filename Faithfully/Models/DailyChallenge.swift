import Foundation

struct DailyChallenge: Codable, Identifiable, Equatable {
    let id: String
    let day: Int
    let title: String
    let category: ChallengeCategory
    let scriptureReference: String
    let scriptureTextESV: String
    let scriptureTextNIV: String
    let scriptureTextNKJV: String
    let challengeDescription: String
    let reflectionPrompt: String
    let difficulty: Difficulty

    func scriptureText(for translation: BibleTranslation) -> String {
        switch translation {
        case .esv: return scriptureTextESV
        case .niv: return scriptureTextNIV
        case .nkjv: return scriptureTextNKJV
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, day, title, category, difficulty
        case scriptureReference = "scripture_reference"
        case scriptureTextESV = "scripture_text_esv"
        case scriptureTextNIV = "scripture_text_niv"
        case scriptureTextNKJV = "scripture_text_nkjv"
        case challengeDescription = "challenge_description"
        case reflectionPrompt = "reflection_prompt"
    }
}
