import SwiftUI
import SwiftData

struct CalendarScreenView: View {
    let vm: CalendarViewModel

    @State private var editingEntry: EditingEntry?

    /// Identifies which day's reflection the sheet is editing.
    private struct EditingEntry: Identifiable {
        let id: UUID
        let date: Date
        let text: String?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack {
                    // Month navigation
                    HStack {
                        Button(action: { vm.previousMonth() }) {
                            Image(systemName: "chevron.left")
                                // A chevron glyph is ~13x17pt. The 44pt minimum
                                // is the tappable area, not the ink: without an
                                // explicit frame this button is a third of the
                                // size a finger needs.
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("previousMonth")

                        Spacer()

                        Text(monthYearString(from: vm.currentMonth))
                            .font(.headline)
                            .accessibilityIdentifier("monthTitle")

                        Spacer()

                        Button(action: { vm.nextMonth() }) {
                            Image(systemName: "chevron.right")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("nextMonth")
                    }
                    .padding(.horizontal)

                    // Day of week headers
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                            Text(day)
                                .font(.caption)
                                // .secondary fails contrast at caption size;
                                // .primary with reduced opacity keeps the visual
                                // hierarchy while staying legible.
                                .foregroundStyle(Color.primary.opacity(0.75))
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.horizontal)

                    // Month grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        // Leading empty cells for alignment
                        ForEach(0..<leadingEmptyDays(for: vm.currentMonth), id: \.self) { _ in
                            Color.clear.frame(height: 40)
                        }

                        ForEach(vm.calendarDays) { day in
                            Button(action: { vm.selectDay(day) }) {
                                Text("\(Calendar.current.component(.day, from: day.date))")
                                    .font(.body)
                                    .frame(width: 36, height: 36)
                                    .background(backgroundForStatus(day.status))
                                    .foregroundStyle(foregroundForStatus(day.status))
                                    .clipShape(Circle())
                            }
                            .accessibilityIdentifier("calendarDay_\(Calendar.current.component(.day, from: day.date))")
                            .accessibilityValue(day.status.accessibilityDescription)
                        }
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("monthGrid")

                    Spacer()

                    // Day detail
                    if let selected = vm.selectedDay {
                        // No container identifier here: applying one to a parent
                        // overwrites every descendant's identifier, so the title,
                        // the pre-enrollment notice, and the Complete button all
                        // became indistinguishable "dayDetail" elements.
                        DayDetailView(
                            day: selected,
                            onComplete: {
                                vm.completeGracePeriod(selected)
                                vm.selectedDay = nil
                            },
                            onEditJournal: { id in
                                editingEntry = EditingEntry(
                                    id: id, date: selected.date, text: selected.journalEntry
                                )
                            }
                        )
                    }
              }
            }
            .navigationTitle("Calendar")
            .sheet(item: $editingEntry) { entry in
                JournalEditSheet(
                    title: entry.text == nil ? "Add reflection" : "Edit reflection",
                    date: entry.date,
                    originalText: entry.text,
                    onSave: { vm.updateJournal(entryID: entry.id, to: $0) },
                    onCancel: { editingEntry = nil }
                )
            }
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func leadingEmptyDays(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let firstOfMonth = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstOfMonth) - 1
    }

    // Colours are paired for contrast, not picked independently. Apple's
    // accessibility audit failed every one of the original pairs: light-on-light
    // for missed and future, and a 40%-opacity secondary for pre-enrollment that
    // no sighted user could read either.
    //
    // Status is also carried by the accessibility value on each day, so nothing
    // here is the *only* signal — but a state that cannot be seen is still a
    // state that does not work.
    private func backgroundForStatus(_ status: CalendarDayStatus) -> Color {
        switch status {
        // Explicit dark fills rather than system accent colours: systemGreen and
        // systemOrange are tuned to be vivid, not to carry white text, and both
        // failed the contrast audit.
        case .completed: return Color(.sRGB, red: 0.08, green: 0.38, blue: 0.20, opacity: 1)
        case .missed: return Color(.systemGray4)
        case .missedRecoverable: return Color(.sRGB, red: 0.60, green: 0.31, blue: 0.02, opacity: 1)
        case .future: return .clear
        case .preEnrollment: return Color(.systemGray6)
        case .today: return Color(.systemBlue).opacity(0.18)
        }
    }

    private func foregroundForStatus(_ status: CalendarDayStatus) -> Color {
        switch status {
        case .completed: return .white
        case .missed: return Color(.label)
        case .missedRecoverable: return .white
        case .future: return Color(.label)
        // Distinguished from .future by its fill rather than by faint text:
        // dimming the text below the contrast floor made the state unreadable
        // rather than merely de-emphasised.
        case .preEnrollment: return Color(.label)
        case .today: return .primary
        }
    }
}
