import SwiftUI

/// The reflection editor, shared by the completion sheet and the edit sheet.
///
/// Extracted rather than copied. The live counter, the over-limit block, the
/// accessible label on the `TextEditor` and the failure line that keeps the
/// draft are the combined output of CLEAN-003 and OPS-004; a second copy would
/// rot independently of this one.
struct JournalEditorView: View {
    @Binding var text: String
    /// Set by the caller when a save failed. Shown next to the counter; the
    /// caller keeps the sheet open and the draft intact.
    var errorMessage: String?

    /// Callers disable their own submit button with this, so the rule that
    /// blocks over-limit text lives with the editor that enforces it.
    static func isOverLimit(_ text: String) -> Bool {
        text.count > Constants.maxJournalLength
    }

    private var characterCount: Int { text.count }
    private var isOverLimit: Bool { Self.isOverLimit(text) }

    /// Spoken as a sentence rather than "1998/2000", which VoiceOver reads as a
    /// date.
    private var counterAccessibilityLabel: String {
        if isOverLimit {
            let over = characterCount - Constants.maxJournalLength
            return "\(over) character\(over == 1 ? "" : "s") over the limit"
        }
        let remaining = Constants.maxJournalLength - characterCount
        return "\(remaining) character\(remaining == 1 ? "" : "s") remaining"
    }

    var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $text)
                // A TextEditor has no implicit label, so VoiceOver announced it
                // as an unnamed text field.
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
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("completionError")
                }
                Spacer()
                Text("\(characterCount)/\(Constants.maxJournalLength)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(isOverLimit ? .red : Color.supportingText)
                    .accessibilityIdentifier("journalCharacterCount")
                    .accessibilityLabel(counterAccessibilityLabel)
                    .accessibilityValue("\(characterCount) of \(Constants.maxJournalLength)")
            }
        }
    }
}
