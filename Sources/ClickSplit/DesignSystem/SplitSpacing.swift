import SwiftUI

/// Click Split layout spacing and corner geometry tokens.
public enum SplitSpacing {
    /// 2pt micro spacing
    public static let xxs: CGFloat = 2

    /// 4pt border / shadow offset unit
    public static let xs: CGFloat = 4

    /// 8pt compact spacing
    public static let sm: CGFloat = 8

    /// 12pt intermediate spacing
    public static let md: CGFloat = 12

    /// 16pt standard content padding
    public static let lg: CGFloat = 16

    /// 20pt section spacing
    public static let xl: CGFloat = 20

    /// 24pt container padding
    public static let xxl: CGFloat = 24

    /// 32pt hero spacing
    public static let xxxl: CGFloat = 32

    /// Border stroke thickness (1pt on standard, crisp retina rendering)
    public static let borderWidth: CGFloat = 1.0

    /// Default subtle shadow offset
    public static let shadowOffset: CGFloat = 2.0

    /// Compact shadow offset for smaller controls
    public static let shadowOffsetSmall: CGFloat = 1.0

    /// Refined corner radius for modern surfaces
    public static let cornerRadius: CGFloat = 8.0

    /// Hard corner radius for strict neo-brutalism
    public static let cornerRadiusZero: CGFloat = 0.0

    /// Rounded pill radius for tags/badges
    public static let cornerRadiusPill: CGFloat = 999.0
}
