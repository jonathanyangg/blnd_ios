import SwiftUI

/// Chip that opens the shared Movies / TV / year sheet.
/// Screens reload from `CatalogFilterStore` when `filter` changes.
struct CatalogFilterButton: View {
    @State private var store = CatalogFilterStore.shared
    @State private var showSheet = false

    var body: some View {
        let filter = store.filter
        Button {
            showSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .semibold))
                Text(filter.chipTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(filter.isActive ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(filter.isActive ? Color.white : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(filter.isActive ? .clear : AppTheme.border, lineWidth: 0.5)
            )
        }
        .accessibilityIdentifier("catalog-filter-button")
        .accessibilityLabel("Filter, \(filter.chipTitle)")
        .sheet(isPresented: $showSheet) {
            CatalogFilterSheet(filter: filter) { updated in
                store.update(updated)
            }
            .presentationDetents([.height(560)])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppTheme.background)
        }
        .onAppear { store.reloadForCurrentUser() }
    }
}

/// Movies / TV / All, release-year chips, and a from/to year slider.
struct CatalogFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CatalogFilter
    let onApply: (CatalogFilter) -> Void

    private var calendarYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    init(filter: CatalogFilter, onApply: @escaping (CatalogFilter) -> Void) {
        _draft = State(initialValue: filter)
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            mediaControl
            yearSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.background)
        .accessibilityIdentifier("catalog-filter-sheet")
        .onDisappear { onApply(draft) }
    }

    private var header: some View {
        HStack {
            Text("Filter")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            if draft.isActive {
                Button("Clear") {
                    draft = CatalogFilter()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .accessibilityIdentifier("catalog-filter-clear")
            }
            Button("Done") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.leading, 12)
                .accessibilityIdentifier("catalog-filter-done")
        }
    }

    private var mediaControl: some View {
        HStack(spacing: 0) {
            ForEach(MediaKind.allCases) { kind in
                let selected = draft.media == kind
                Button {
                    draft.media = kind
                } label: {
                    Text(kind.label)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? Color.white : Color.clear)
                        .foregroundStyle(selected ? Color.black : AppTheme.textMuted)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("catalog-filter-media-\(kind.rawValue)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(AppTheme.card)
        .clipShape(Capsule())
    }

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Release date")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textMuted)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                spacing: 8
            ) {
                ForEach(ReleasePreset.allCases) { preset in
                    presetChip(preset)
                }
            }

            yearSlider
        }
    }

    private func presetChip(_ preset: ReleasePreset) -> some View {
        let selected = draft.preset == preset
        return Button {
            if selected {
                draft.yearMin = nil
                draft.yearMax = nil
                draft.preset = nil
            } else {
                draft.apply(preset, calendarYear: calendarYear)
            }
        } label: {
            Text(preset.title)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Color.white : AppTheme.card)
                .foregroundStyle(selected ? Color.black : .white)
                .clipShape(Capsule())
        }
        .accessibilityIdentifier("catalog-filter-preset-\(preset.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var yearSlider: some View {
        let upper = CatalogFilter.sliderUpper(calendarYear: calendarYear)
        return VStack(alignment: .leading, spacing: 8) {
            Text(draft.yearMin == nil && draft.yearMax == nil ? "Any year" : draft.yearLabel)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            sliderRow("From", value: minBinding, upper: upper, identifier: "catalog-filter-year-min")
            sliderRow("To", value: maxBinding, upper: upper, identifier: "catalog-filter-year-max")
        }
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        upper: Int,
        identifier: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .frame(width: 36, alignment: .leading)
            Slider(
                value: value,
                in: Double(CatalogFilter.sliderLower) ... Double(upper),
                step: 1
            )
            .tint(.white)
            .accessibilityIdentifier(identifier)
        }
    }

    private var minBinding: Binding<Double> {
        Binding(
            get: { Double(draft.yearMin ?? CatalogFilter.sliderLower) },
            set: { draft.setYearMin(Int($0.rounded()), calendarYear: calendarYear) }
        )
    }

    private var maxBinding: Binding<Double> {
        Binding(
            get: {
                Double(
                    draft.yearMax
                        ?? CatalogFilter.sliderUpper(calendarYear: calendarYear)
                )
            },
            set: { draft.setYearMax(Int($0.rounded()), calendarYear: calendarYear) }
        )
    }
}

struct CatalogFilterNotice: View {
    let title: String
    var button: String?
    var onButton: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let button, let onButton {
                Button(button, action: onButton)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("catalog-filter-notice-action")
            }
        }
        .padding(.horizontal, 32)
        .accessibilityIdentifier("catalog-filter-notice")
    }
}

/// Full-screen stand-in so the simulator can open the sheet without a session.
/// `-catalogFilterSample` opens TV plus the 2020s chip.
struct CatalogFilterScreenshotHost: View {
    private var initial: CatalogFilter {
        guard ProcessInfo.processInfo.arguments.contains("-catalogFilterSample") else {
            return CatalogFilter()
        }
        var filter = CatalogFilter()
        filter.media = .tv
        let year = Calendar.current.component(.year, from: Date())
        filter.apply(.twenties, calendarYear: year)
        return filter
    }

    var body: some View {
        CatalogFilterSheet(filter: initial, onApply: { _ in })
    }
}
