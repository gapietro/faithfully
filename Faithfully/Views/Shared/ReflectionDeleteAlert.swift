import SwiftUI

/// Shared copy and presentation for the "delete this reflection" confirmation.
///
/// Extracted after the two independent copies — in `JourneyView` and inside
/// `JournalEditSheet` — had already drifted apart in wording. Both routes
/// delete the same thing for the same reason, so they get one definition of
/// what it says.
///
/// `.alert` rather than `.confirmationDialog`: on this platform a two-action
/// confirmationDialog collapses to a popover exposing only the destructive
/// button, with "Cancel" reachable solely by tapping outside. For an
/// irreversible delete of private writing, Cancel must be a visible, explicit
/// control — an alert renders both buttons on every size class.
enum ReflectionDeleteAlert {
    static let title = "Delete this reflection?"

    /// `date` is included when the caller already has one specific day in
    /// view (the edit sheet); omitted where the alert speaks generically about
    /// "your reflection" over a list of entries (the Journey timeline).
    static func message(for date: Date? = nil) -> String {
        let subject = date.map {
            "Your reflection for \($0.formatted(.dateTime.day().month(.wide).year()))"
        } ?? "Your reflection"
        return "\(subject) will be permanently deleted. The day stays completed — "
            + "your streak and badges aren't affected."
    }
}

extension View {
    /// Attaches the shared delete-reflection confirmation alert.
    func reflectionDeleteAlert(
        isPresented: Binding<Bool>,
        date: Date? = nil,
        onDelete: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        alert(ReflectionDeleteAlert.title, isPresented: isPresented) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel, action: onCancel)
        } message: {
            Text(ReflectionDeleteAlert.message(for: date))
        }
    }
}
