import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Neo-brutalist color palette for Click Split with full dynamic Light/Dark mode support.
/// Matching exact web token definitions.
public enum SplitColors {
    #if canImport(UIKit)
    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Background paper tone: #FAF8F3 in light, #121212 in dark
    public static let paper = dynamicColor(
        light: UIColor(red: 250 / 255.0, green: 248 / 255.0, blue: 243 / 255.0, alpha: 1.0),
        dark: UIColor(red: 18 / 255.0, green: 18 / 255.0, blue: 18 / 255.0, alpha: 1.0)
    )

    /// Dimmed paper tone for card backgrounds and nested surfaces: #F1EEE5 in light, #1E1E20 in dark
    public static let paperDim = dynamicColor(
        light: UIColor(red: 241 / 255.0, green: 238 / 255.0, blue: 229 / 255.0, alpha: 1.0),
        dark: UIColor(red: 30 / 255.0, green: 30 / 255.0, blue: 32 / 255.0, alpha: 1.0)
    )

    /// Primary ink text and outlines: #141414 in light, #F5F5F0 in dark
    public static let ink = dynamicColor(
        light: UIColor(red: 20 / 255.0, green: 20 / 255.0, blue: 20 / 255.0, alpha: 1.0),
        dark: UIColor(red: 245 / 255.0, green: 245 / 255.0, blue: 240 / 255.0, alpha: 1.0)
    )

    /// Secondary ink for subtitles and metadata: #4A473F in light, #A3A099 in dark
    public static let inkSoft = dynamicColor(
        light: UIColor(red: 74 / 255.0, green: 71 / 255.0, blue: 63 / 255.0, alpha: 1.0),
        dark: UIColor(red: 163 / 255.0, green: 160 / 255.0, blue: 153 / 255.0, alpha: 1.0)
    )

    /// Tertiary neutral grey: #8A8577 in light, #737068 in dark
    public static let grey = dynamicColor(
        light: UIColor(red: 138 / 255.0, green: 133 / 255.0, blue: 119 / 255.0, alpha: 1.0),
        dark: UIColor(red: 115 / 255.0, green: 112 / 255.0, blue: 104 / 255.0, alpha: 1.0)
    )

    /// Primary action and positive balance green: #0E9F5A in light, #10B981 in dark
    public static let green = dynamicColor(
        light: UIColor(red: 14 / 255.0, green: 159 / 255.0, blue: 90 / 255.0, alpha: 1.0),
        dark: UIColor(red: 16 / 255.0, green: 185 / 255.0, blue: 129 / 255.0, alpha: 1.0)
    )

    /// Muted green background for badges and positive highlights: #E4F3EA in light, #133E2B in dark
    public static let greenDim = dynamicColor(
        light: UIColor(red: 228 / 255.0, green: 243 / 255.0, blue: 234 / 255.0, alpha: 1.0),
        dark: UIColor(red: 19 / 255.0, green: 62 / 255.0, blue: 43 / 255.0, alpha: 1.0)
    )

    /// Debt and negative balance red: #D64545 in light, #EF4444 in dark
    public static let red = dynamicColor(
        light: UIColor(red: 214 / 255.0, green: 69 / 255.0, blue: 69 / 255.0, alpha: 1.0),
        dark: UIColor(red: 239 / 255.0, green: 68 / 255.0, blue: 68 / 255.0, alpha: 1.0)
    )

    /// Muted red background for debt badges and negative highlights: #FBEAEA in light, #3D1A1A in dark
    public static let redDim = dynamicColor(
        light: UIColor(red: 251 / 255.0, green: 234 / 255.0, blue: 234 / 255.0, alpha: 1.0),
        dark: UIColor(red: 61 / 255.0, green: 26 / 255.0, blue: 26 / 255.0, alpha: 1.0)
    )

    /// Pure white in light mode, elevated card surface in dark mode
    public static let white = dynamicColor(
        light: UIColor.white,
        dark: UIColor(red: 36 / 255.0, green: 36 / 255.0, blue: 38 / 255.0, alpha: 1.0)
    )

    /// Subtle outline border color: soft neutral in light, subtle translucent ink in dark
    public static let border = dynamicColor(
        light: UIColor(red: 20 / 255.0, green: 20 / 255.0, blue: 20 / 255.0, alpha: 0.12),
        dark: UIColor(red: 245 / 255.0, green: 245 / 255.0, blue: 240 / 255.0, alpha: 0.15)
    )
    #else
    public static let paper = Color(red: 250 / 255.0, green: 248 / 255.0, blue: 243 / 255.0)
    public static let paperDim = Color(red: 241 / 255.0, green: 238 / 255.0, blue: 229 / 255.0)
    public static let ink = Color(red: 20 / 255.0, green: 20 / 255.0, blue: 20 / 255.0)
    public static let inkSoft = Color(red: 74 / 255.0, green: 71 / 255.0, blue: 63 / 255.0)
    public static let grey = Color(red: 138 / 255.0, green: 133 / 255.0, blue: 119 / 255.0)
    public static let green = Color(red: 14 / 255.0, green: 159 / 255.0, blue: 90 / 255.0)
    public static let greenDim = Color(red: 228 / 255.0, green: 243 / 255.0, blue: 234 / 255.0)
    public static let red = Color(red: 214 / 255.0, green: 69 / 255.0, blue: 69 / 255.0)
    public static let redDim = Color(red: 251 / 255.0, green: 234 / 255.0, blue: 234 / 255.0)
    public static let white = Color.white
    public static let border = Color(red: 20 / 255.0, green: 20 / 255.0, blue: 20 / 255.0).opacity(0.12)
    #endif
}
