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

                // Say why there is no button rather than just omitting one, so a
                // pre-enrollment day doesn't read as a bug or a missed chance.
                if day.status == .preEnrollment {
                    Text("This day is before you started Faithfully.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("preEnrollmentNotice")
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
