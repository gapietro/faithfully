import Foundation

struct ShareCardData {
    let title: String
    let category: ChallengeCategory
    let date: Date
    let scriptureReference: String
    let journalText: String
    let streakCount: Int

    /// Plain-text rendering for the system share sheet.
    var shareText: String {
        var lines: [String] = [
            title,
            date.formatted(date: .abbreviated, time: .omitted),
            scriptureReference
        ]
        if !journalText.isEmpty {
            lines.append("")
            lines.append(journalText)
        }
        lines.append("")
        lines.append("\(streakCount) day streak on Faithfully")
        return lines.joined(separator: "\n")
    }
}
