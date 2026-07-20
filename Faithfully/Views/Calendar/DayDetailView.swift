import SwiftUI

struct DayDetailView: View {
    let day: CalendarDay
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let challenge = day.challenge {
                Text(challenge.title)
                    .font(.headline)
                    .accessibilityIdentifier("calendarDetailTitle")
                Text(challenge.challengeDescription)
                    .font(.body)

                if let journal = day.journalEntry {
                    Text("Journal: \(journal)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                // Today is completable here too — before the .today status
                // existed it rode the grace path, and losing that would regress
                // completing today from the calendar.
                if day.status == .missedRecoverable || day.status == .today {
                    Button("Complete Now") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("gracePeriodComplete")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
