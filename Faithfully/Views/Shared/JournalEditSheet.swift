import SwiftUI

/// Edits the reflection on one completed day.
///
/// Saving is a closure returning a result rather than a plain callback, for the
/// same reason completion is: the sheet must not dismiss or discard the draft
/// until it knows the write landed.
struct JournalEditSheet: View {
    let title: String
    let date: Date
    let originalText: String?
    let onSave: (String?) -> JournalEditResult
    let onCancel: () -> Void

    @State private var text: String
    @State private var errorMessage: String?
    @State private var confirmingClear = false

    init(
        title: String,
        date: Date,
        originalText: String?,
        onSave: @escaping (String?) -> JournalEditResult,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.date = date
        self.originalText = originalText
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: originalText ?? "")
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Saving empty text over existing text destroys writing just as thoroughly
    /// as swiping to delete, so it takes the same confirmation.
    private var wouldClearExistingText: Bool {
        trimmed.isEmpty && !(originalText ?? "").isEmpty
    }

    private var isOverLimit: Bool { JournalEditorView.isOverLimit(text) }

    private var formattedDate: String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(Color(.label))
                    .frame(maxWidth: .infinity)

                JournalEditorView(text: $text, errorMessage: errorMessage)

                Button(action: attemptSave) {
                    Text("Save")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isOverLimit ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isOverLimit)
                .accessibilityIdentifier("saveJournalButton")

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancelJournalEdit")
                }
            }
        }
        .presentationDetents([.medium])
        // Explicit, not a material: contrast measured against a blurred backdrop
        // depends on whatever the user was looking at a moment ago.
        .presentationBackground(Color(.systemBackground))
        .confirmationDialog(
            "Delete this reflection?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { commit(nil) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your reflection for \(formattedDate) will be permanently deleted. "
                 + "The day stays completed — your streak and badges aren't affected.")
        }
    }

    private func attemptSave() {
        if wouldClearExistingText {
            confirmingClear = true
        } else {
            commit(trimmed.isEmpty ? nil : text)
        }
    }

    private func commit(_ value: String?) {
        switch onSave(value) {
        case .saved:
            errorMessage = nil
            onCancel()
        case .failed(let failure):
            // Sheet stays open, draft intact.
            errorMessage = failure.message
        }
    }
}
