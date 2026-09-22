import SwiftUI

/// Standard motion curves and durations for Click Split.
public enum SplitMotion {
    /// Quick snappy transition for button depression and tab selection
    public static let quick = Animation.easeInOut(duration: 0.12)

    /// Standard interactive transition for sheets and toggles
    public static let standard = Animation.spring(response: 0.28, dampingFraction: 0.85)

    /// Energetic feedback animation for success confirmations
    public static let pop = Animation.spring(response: 0.35, dampingFraction: 0.7)
}
