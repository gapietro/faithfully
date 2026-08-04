import SwiftUI

struct DayDetailView: View {
    let day: CalendarDay
    /// Set when the last completion attempt failed. The panel stays open and
    /// shows this, rather than dismissing as if the day had been recorded.
    var completionError: String?
    let onComplete: () -> Void
    /// Called with the day's completion id when the user wants to write or
    /// change its reflection.
    let onEditJournal: (UUID) -> Void

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
                        .foregroundStyle(Color.supportingText)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Reachable for every completed day, including one with no
                // reflection — this is the only route back to a day whose text
                // was cleared from the Journey timeline.
                if let completionID = day.completionID {
                    Button(day.journalEntry == nil ? "Add reflection" : "Edit reflection") {
                        onEditJournal(completionID)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("editJournalButton")
                }

                // Say why there is no button rather than just omitting one, so a
                // pre-enrollment day doesn't read as a bug or a missed chance.
                if day.status == .preEnrollment {
                    Text("This day is before you started Faithfully.")
                        .font(.footnote)
                        .foregroundStyle(Color.supportingText)
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

                if let completionError {
                    Text(completionError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("dayCompletionError")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}
