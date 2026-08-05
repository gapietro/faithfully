import SwiftUI
import SwiftData

struct CalendarScreenView: View {
    let vm: CalendarViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack {
                    // Month navigation
                    HStack {
                        Button(action: { vm.previousMonth() }) {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityIdentifier("previousMonth")

                        Spacer()

                        Text(monthYearString(from: vm.currentMonth))
                            .font(.headline)
                            .accessibilityIdentifier("monthTitle")

                        Spacer()

                        Button(action: { vm.nextMonth() }) {
                            Image(systemName: "chevron.right")
                        }
                        .accessibilityIdentifier("nextMonth")
                    }
                    .padding(.horizontal)

                    // Day of week headers
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                            Text(day)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                        }
                    }
                    .padding(.horizontal)
                    .accessibilityIdentifier("monthGrid")

                    Spacer()

                    // Day detail
                    if let selected = vm.selectedDay {
                        DayDetailView(day: selected) {
                            vm.completeGracePeriod(selected)
                            vm.selectedDay = nil
                        }
                        .accessibilityIdentifier("dayDetail")
                    }
              }
            }
            .navigationTitle("Calendar")
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

    private func backgroundForStatus(_ status: CalendarDayStatus) -> Color {
        switch status {
        case .completed: return .green
        case .missed: return .gray.opacity(0.2)
        case .missedRecoverable: return .orange.opacity(0.3)
        case .future: return .clear
        case .today: return .blue.opacity(0.2)
        case .unavailable: return .clear
        }
    }

    private func foregroundForStatus(_ status: CalendarDayStatus) -> Color {
        switch status {
        case .completed: return .white
        case .missed: return .gray
        case .missedRecoverable: return .orange
        case .future: return .secondary
        case .today: return .primary
        case .unavailable: return .secondary.opacity(0.5)
        }
    }
}
