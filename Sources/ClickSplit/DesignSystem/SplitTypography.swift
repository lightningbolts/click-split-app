import SwiftUI

/// Click Split typography system.
/// Uses system font with heavy weights and monospaced digits for amounts.
public enum SplitTypography {
    /// Hero financial amounts ($214.37)
    public static let amountHero: Font = .system(size: 38, weight: .black, design: .default)

    /// Large section balance ($84.20)
    public static let amountLarge: Font = .system(size: 28, weight: .bold, design: .default)

    /// Card balance and feed amounts ($120.00)
    public static let amountMedium: Font = .system(size: 20, weight: .bold, design: .default)

    /// Inline amounts and item prices ($14.00)
    public static let amountSmall: Font = .system(size: 16, weight: .bold, design: .default)

    /// Page and group titles
    public static let title: Font = .system(size: 24, weight: .bold, design: .default)

    /// Subtitles and section headers
    public static let sectionHeader: Font = .system(size: 14, weight: .heavy, design: .default)

    /// Body text
    public static let body: Font = .system(size: 15, weight: .medium, design: .default)

    /// Bold button labels
    public static let button: Font = .system(size: 16, weight: .bold, design: .default)

    /// Small button labels
    public static let buttonSmall: Font = .system(size: 13, weight: .bold, design: .default)

    /// Metadata, timestamps, and subtitles
    public static let caption: Font = .system(size: 12, weight: .semibold, design: .default)

    /// Uppercase tag / badge text
    public static let badge: Font = .system(size: 11, weight: .heavy, design: .default)
}

public extension View {
    /// Applies tabular monospaced digits to prevent visual shifting of financial values.
    func splitMonospacedDigits() -> some View {
        self.monospacedDigit()
    }
}
