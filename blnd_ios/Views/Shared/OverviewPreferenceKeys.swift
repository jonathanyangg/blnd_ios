import SwiftUI

enum OverviewFullH: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = max(value, nextValue())
    }
}

enum OverviewTruncH: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = max(value, nextValue())
    }
}
