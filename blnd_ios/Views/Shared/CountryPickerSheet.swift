import PhoneNumberKit
import SwiftUI

/// Searchable list of countries sourced from PhoneNumberKit's region data.
struct CountryPickerSheet: View {
    @Binding var selectedRegion: String
    let phoneUtility: PhoneNumberUtility

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var countries: [CountryEntry] {
        phoneUtility.allCountries()
            .filter { $0 != "001" } // "001" is the generic non-geographic region
            .compactMap { region -> CountryEntry? in
                guard let dialCode = phoneUtility.countryCode(for: region) else {
                    return nil
                }
                let name = Locale.current.localizedString(
                    forRegionCode: region
                ) ?? region
                return CountryEntry(
                    region: region,
                    name: name,
                    dialCode: "\(dialCode)",
                    flag: Self.flag(forRegion: region)
                )
            }
            .sorted { $0.name < $1.name }
    }

    private var filtered: [CountryEntry] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return countries }
        return countries.filter {
            $0.name.lowercased().contains(query)
                || $0.dialCode.contains(query)
                || $0.region.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { entry in
                            countryRow(entry)
                            Divider()
                                .background(AppTheme.cardSecondary)
                                .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func countryRow(_ entry: CountryEntry) -> some View {
        Button {
            selectedRegion = entry.region
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(entry.flag)
                    .font(.system(size: 22))
                Text(entry.name)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                Spacer()
                Text("+\(entry.dialCode)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textMuted)
                if entry.region == selectedRegion {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textDim)
            TextField("", text: $searchText, prompt: searchPrompt)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(10)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var searchPrompt: Text {
        Text("Search country or code")
            .foregroundStyle(AppTheme.textDim)
    }

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

// MARK: - CountryEntry

private struct CountryEntry: Identifiable {
    let region: String
    let name: String
    let dialCode: String
    let flag: String

    var id: String {
        region
    }
}
