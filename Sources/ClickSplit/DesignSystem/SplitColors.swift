import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Neo-brutalist color palette for Click Split.
/// Matching exact web token definitions.
public enum SplitColors {
    /// Background paper tone: #FAF8F3
    public static let paper = Color(red: 250 / 255.0, green: 248 / 255.0, blue: 243 / 255.0)

    /// Dimmed paper tone for card backgrounds and nested surfaces: #F1EEE5
    public static let paperDim = Color(red: 241 / 255.0, green: 238 / 255.0, blue: 229 / 255.0)

    /// Primary ink text and outlines: #141414
    public static let ink = Color(red: 20 / 255.0, green: 20 / 255.0, blue: 20 / 255.0)

    /// Secondary ink for subtitles and metadata: #4A473F
    public static let inkSoft = Color(red: 74 / 255.0, green: 71 / 255.0, blue: 63 / 255.0)

    /// Tertiary neutral grey: #8A8577
    public static let grey = Color(red: 138 / 255.0, green: 133 / 255.0, blue: 119 / 255.0)

    /// Primary action and positive balance green: #0E9F5A
    public static let green = Color(red: 14 / 255.0, green: 159 / 255.0, blue: 90 / 255.0)

    /// Muted green background for badges and positive highlights: #E4F3EA
    public static let greenDim = Color(red: 228 / 255.0, green: 243 / 255.0, blue: 234 / 255.0)

    /// Debt and negative balance red: #D64545
    public static let red = Color(red: 214 / 255.0, green: 69 / 255.0, blue: 69 / 255.0)

    /// Muted red background for debt badges and negative highlights: #FBEAEA
    public static let redDim = Color(red: 251 / 255.0, green: 234 / 255.0, blue: 234 / 255.0)

    /// Pure white for high-contrast badge insets
    public static let white = Color.white
}
