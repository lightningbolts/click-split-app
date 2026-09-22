import SwiftUI

/// Distinct styles for Click Split buttons.
public enum SplitButtonVariant {
    case primary    // Green background, white text, ink outline
    case secondary  // Paper dim background, ink text, ink outline
    case danger     // Red background, white text, ink outline
    case ghost      // Border only or subtle ink
}

/// Neo-brutalist button component with hard outline and offset press effect.
public struct SplitButton: View {
    public var title: String
    public var icon: String?
    public var variant: SplitButtonVariant
    public var isLoading: Bool
    public var action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        variant: SplitButtonVariant = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.isLoading = isLoading
        self.action = action
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: return SplitColors.green
        case .secondary: return SplitColors.paperDim
        case .danger: return SplitColors.red
        case .ghost: return SplitColors.paper
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .danger: return SplitColors.white
        case .secondary, .ghost: return SplitColors.ink
        }
    }

    public var body: some View {
        Button(action: {
            SplitHaptics.impact(.medium)
            action()
        }) {
            HStack(spacing: SplitSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(title)
                        .font(SplitTypography.button)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            SplitPressableButtonStyle(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
                borderColor: SplitColors.ink,
                shadowOffset: SplitSpacing.shadowOffset,
                cornerRadius: SplitSpacing.cornerRadius
            )
        )
        .disabled(isLoading)
    }
}
