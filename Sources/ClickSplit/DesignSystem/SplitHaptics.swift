import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Tactile feedback utilities for intentional touch responses.
public enum SplitHaptics {
    /// Light tap feedback for selections and toggles
    public static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Impact feedback for primary actions and button confirmations
    public static func impact(_ style: ImpactStyle = .medium) {
        #if canImport(UIKit)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: feedbackStyle = .light
        case .medium: feedbackStyle = .medium
        case .heavy: feedbackStyle = .heavy
        }
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        #endif
    }

    /// Notification feedback for success or error states
    public static func notify(_ type: NotificationType) {
        #if canImport(UIKit)
        let feedbackType: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success: feedbackType = .success
        case .warning: feedbackType = .warning
        case .error: feedbackType = .error
        }
        UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
        #endif
    }

    public enum ImpactStyle: Sendable {
        case light
        case medium
        case heavy
    }

    public enum NotificationType: Sendable {
        case success
        case warning
        case error
    }
}
