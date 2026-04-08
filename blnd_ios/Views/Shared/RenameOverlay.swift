import SwiftUI

struct RenameOverlay: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @FocusState private var isFocused: Bool

    var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(AppTheme.textDim))
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppTheme.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.border, lineWidth: 0.5)
                    )
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if !trimmed.isEmpty { save() }
                    }

                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(AppTheme.cardSecondary)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(trimmed.isEmpty ? AppTheme.border : .white)
                            .foregroundStyle(trimmed.isEmpty ? AppTheme.textDim : .black)
                            .clipShape(Capsule())
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
            .padding(28)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.border, lineWidth: 0.5)
            )
            .padding(.horizontal, 44)
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave()
        dismiss()
    }

    private func dismiss() {
        isFocused = false
        withAnimation(.easeOut(duration: 0.15)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDismiss()
        }
    }
}
