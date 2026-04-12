import PhoneNumberKit
import SwiftUI

/// Phone input with a compact country code picker + local number field.
///
/// - Country list and dial codes sourced from PhoneNumberKit
/// - Format-as-you-type via `PartialFormatter`
/// - Writes E.164 output to `phoneNumber` (e.g. "+15551234567"),
///   or empty string when the field is cleared
/// - Defaults to US
struct PhoneNumberInputField: View {
    @Binding var phoneNumber: String

    @State private var selectedRegion: String = "US"
    @State private var localInput: String = ""
    @State private var showCountryPicker = false

    private let phoneUtility = PhoneNumberUtility()

    private var dialCode: String {
        let code = phoneUtility.countryCode(for: selectedRegion) ?? 1
        return "\(code)"
    }

    private var flagEmoji: String {
        Self.flag(forRegion: selectedRegion)
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                showCountryPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(flagEmoji)
                        .font(.system(size: 18))
                    Text("+\(dialCode)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }

            TextField("", text: $localInput, prompt: promptText)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(16)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                .onChange(of: localInput) { _, newValue in
                    formatAndUpdate(rawInput: newValue)
                }
                .onChange(of: selectedRegion) { _, _ in
                    // Re-format the existing input when country changes
                    formatAndUpdate(rawInput: localInput)
                }
        }
        .padding(.bottom, 12)
        .sheet(isPresented: $showCountryPicker) {
            CountryPickerSheet(
                selectedRegion: $selectedRegion,
                phoneUtility: phoneUtility
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
        }
    }

    private var promptText: Text {
        Text("Phone number (optional)")
            .foregroundStyle(AppTheme.textMuted)
    }

    // MARK: - Formatting + E.164 output

    private func formatAndUpdate(rawInput: String) {
        let digits = rawInput.filter(\.isNumber)

        // Format for display using the selected region
        let formatter = PartialFormatter(
            defaultRegion: selectedRegion,
            withPrefix: false
        )
        let formatted = formatter.formatPartial(digits)
        if formatted != localInput {
            localInput = formatted
        }

        // Produce E.164 output for the parent binding
        if digits.isEmpty {
            phoneNumber = ""
            return
        }
        do {
            let parsed = try phoneUtility.parse(digits, withRegion: selectedRegion)
            phoneNumber = phoneUtility.format(parsed, toType: .e164)
        } catch {
            // Still-typing / not yet a valid number — store the best-effort E.164
            phoneNumber = "+\(dialCode)\(digits)"
        }
    }

    // MARK: - Flag emoji from ISO region code

    private static func flag(forRegion region: String) -> String {
        let base: UInt32 = 127_397
        var flag = ""
        for scalar in region.uppercased().unicodeScalars {
            if let flagScalar = Unicode.Scalar(base + scalar.value) {
                flag.append(String(flagScalar))
            }
        }
        return flag
    }
}
