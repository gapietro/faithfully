import SwiftUI

/// Shown when the on-disk store could not be opened and the app is running on an
/// in-memory stand-in.
///
/// A banner rather than a blocking screen: the challenge itself is bundled
/// content and still works, so the user keeps today's walk. What they must not
/// do is write a journal entry believing it was kept, so the banner is
/// persistent and states plainly that nothing is being saved.
///
/// The reset confirmation is an `.alert`, not a `.confirmationDialog`: on this
/// platform a two-action confirmationDialog collapses to a popover exposing
/// only the destructive button, leaving Cancel reachable solely by tapping
/// outside and absent from the accessibility tree entirely. Reset moves the
/// user's whole store aside, so Cancel has to be a visible, explicit control —
/// an alert renders both buttons on every size class. Same reasoning as
/// `ReflectionDeleteAlert`.
struct StoreUnavailableBanner: View {
    let message: String
    let onReset: () -> Void

    @State private var confirmingReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Your saved data isn't available", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Color.supportingText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Reset Saved Data…") { confirmingReset = true }
                .font(.footnote.weight(.medium))
                .accessibilityIdentifier("resetStoreButton")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        // `.contain` so the banner is one addressable container without
        // swallowing its children's identifiers: a bare
        // `.accessibilityIdentifier` here overwrote every child's, which left
        // the reset button's own identifier dead and unreachable.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("storeUnavailableBanner")
        .alert("Reset saved data?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { onReset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your unreadable data file is moved aside, not deleted, and Faithfully starts "
                 + "a fresh one. Completions and journal entries in the old file will not appear.")
        }
    }
}
