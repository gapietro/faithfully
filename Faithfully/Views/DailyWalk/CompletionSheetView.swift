import SwiftUI

struct CompletionSheetView: View {
    @Binding var journalText: String
    /// Set by the caller when a completion attempt failed. The sheet stays open
    /// and the draft stays intact whenever this is non-nil.
    var errorMessage: String?
    let onComplete: () -> Void

    private var isOverLimit: Bool { JournalEditorView.isOverLimit(journalText) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How did it go?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                Text("A short reflection, if you like")
                    .font(.subheadline)
                    // Full label colour: the sheet's background defeated every
                    // reduced-opacity variant in the accessibility audit.
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                JournalEditorView(text: $journalText, errorMessage: errorMessage)

                Button(action: onComplete) {
                    Text("Complete Challenge")
                        .font(.headline)
                        // Clipped at large Dynamic Type sizes before this.
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isOverLimit ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                // Blocked at the source: the user can never submit text that
                // would be rejected after the fact.
                .disabled(isOverLimit)
                .accessibilityIdentifier("completeButton")
                .accessibilityHint(isOverLimit
                    ? "Unavailable until your reflection is within the character limit"
                    : "")

                Spacer()
            }
            .padding()
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        // An explicit background rather than the default material. A material
        // blends whatever is behind the sheet, so text contrast depended on the
        // screen underneath — it passed locally and failed in CI for that reason.
        .presentationBackground(Color(.systemBackground))
    }
}
