import SwiftUI

struct CompletionSheetView: View {
    @Binding var journalText: String
    /// Set by the caller when a completion attempt failed. The sheet stays open
    /// and the draft stays intact whenever this is non-nil.
    var errorMessage: String?
    let onComplete: () -> Void

    private var characterCount: Int { journalText.count }
    private var isOverLimit: Bool { characterCount > Constants.maxJournalLength }

    /// Spoken as a sentence rather than "1998/2000", which VoiceOver reads as a
    /// date. Announced only near the limit so it isn't noise on an empty editor.
    private var counterAccessibilityLabel: String {
        if isOverLimit {
            let over = characterCount - Constants.maxJournalLength
            return "\(over) character\(over == 1 ? "" : "s") over the limit"
        }
        let remaining = Constants.maxJournalLength - characterCount
        return "\(remaining) character\(remaining == 1 ? "" : "s") remaining"
    }

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
                    // reduced-opacity variant in the audit, and this line tells
                    // the user the field is optional — not decoration.
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                TextEditor(text: $journalText)
                    // A TextEditor has no implicit label, so VoiceOver announced
                    // it as an unnamed text field — the audit's "Element has no
                    // description".
                    .accessibilityLabel("Your reflection")
                    .accessibilityHint("Optional. Up to \(Constants.maxJournalLength) characters.")
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isOverLimit ? Color.red : Color.gray.opacity(0.3))
                    )
                    .accessibilityIdentifier("journalEditor")

                HStack {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("completionError")
                    }
                    Spacer()
                    Text("\(characterCount)/\(Constants.maxJournalLength)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(isOverLimit ? .red : .secondary)
                        .accessibilityIdentifier("journalCharacterCount")
                        .accessibilityLabel(counterAccessibilityLabel)
                        .accessibilityValue("\(characterCount) of \(Constants.maxJournalLength)")
                }

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
                // would be rejected or trimmed after the fact.
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
    }
}
