import Foundation

enum ChallengeCategory: String, Codable, CaseIterable, Identifiable {
    case prayer
    case scripture
    case obedience
    case giving
    case evangelism
    case spiritualWarfare
    case discipline
    case worshipAndThanks
    case service
    case growth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .prayer: return "Prayer"
        case .scripture: return "Scripture"
        case .obedience: return "Obedience"
        case .giving: return "Giving"
        case .evangelism: return "Evangelism"
        case .spiritualWarfare: return "Spiritual Warfare"
        case .discipline: return "Discipline"
        case .worshipAndThanks: return "Worship & Thanks"
        case .service: return "Service"
        case .growth: return "Growth"
        }
    }
}
