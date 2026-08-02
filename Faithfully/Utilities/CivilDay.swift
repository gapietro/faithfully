import Foundation

/// A calendar day, identified independently of any instant.
///
/// ## Why this exists
///
/// Completions used to be identified by a `Date` — an absolute instant, stored
/// as `scheduledDate.startOfDay` — and every later read reinterpreted that
/// instant through whatever `Calendar.current` the device happened to have.
/// Complete a challenge near midnight, fly across the date line, relaunch, and
/// the same stored instant resolves to a *different* calendar day: the
/// completion moves in the grid, or falls outside a month query entirely, and
/// the streak silently breaks.
///
/// A civil day is not an instant. It is "the 15th of June, 2026" — a fact that
/// does not change when the reader moves. Representing it as one is the only
/// way to keep it stable.
///
/// ## The policy
///
/// A completion is recorded against **the user's local calendar day at the
/// moment they complete it**, and that day is then frozen. Reads never
/// recompute it from an instant.
///
/// "Today" is always the user's *current* local day. So a user who travels sees
/// their new local today going forward, while every day they already completed
/// keeps the date it was completed on. Both halves of that are what a person
/// would expect; the old model got the second half wrong.
///
/// The key is `yyyyMMdd` as an `Int` — human-readable in a debugger, sorts
/// chronologically, and is directly usable in a SwiftData predicate, which an
/// opaque struct is not.
enum CivilDay {
    /// The civil day `date` falls on, in `calendar`.
    static func key(for date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        // A calendar always yields these three for a valid date; the fallbacks
        // exist only to avoid trapping, and produce a key that sorts before any
        // real one rather than a plausible-looking wrong date.
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return year * 10_000 + month * 100 + day
    }

    /// A representative instant for `key`, anchored at noon so that a DST
    /// transition at or near midnight cannot push it into an adjacent day.
    static func date(for key: Int, calendar: Calendar = .current) -> Date? {
        var components = DateComponents()
        components.year = key / 10_000
        components.month = (key / 100) % 100
        components.day = key % 100
        components.hour = 12
        return calendar.date(from: components)
    }

    /// `key` shifted by `days`, following the calendar rather than adding
    /// 86,400 seconds — a DST day is 23 or 25 hours long, and arithmetic on
    /// seconds silently skips or repeats a day twice a year.
    static func key(_ key: Int, offsetByDays days: Int, calendar: Calendar = .current) -> Int? {
        guard let anchor = date(for: key, calendar: calendar),
              let shifted = calendar.date(byAdding: .day, value: days, to: anchor) else { return nil }
        return Self.key(for: shifted, calendar: calendar)
    }

    /// Whole calendar days from `start` to `end`; negative when `end` precedes
    /// `start`. Nil only if either key is not a real date.
    static func daysBetween(_ start: Int, _ end: Int, calendar: Calendar = .current) -> Int? {
        guard let from = date(for: start, calendar: calendar),
              let to = date(for: end, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: from, to: to).day
    }
}
