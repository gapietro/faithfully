import SwiftUI

struct CompletionSheetView: View {
    @Binding var journalText: String
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How did it go?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Write a short reflection (optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $journalText)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                    .accessibilityIdentifier("journalEditor")

                Button(action: onComplete) {
                    Text("Complete Challenge")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("completeButton")

                Spacer()
            }
            .padding()
            .navigationTitle("Reflection")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
