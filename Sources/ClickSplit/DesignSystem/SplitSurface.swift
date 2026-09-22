import SwiftUI

/// View modifiers implementing Click Split's neo-brutalist surfaces, borders, and hard offset shadows.
public struct SplitSurfaceModifier: ViewModifier {
    public var backgroundColor: Color
    public var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
    }
}

public struct SplitBorderModifier: ViewModifier {
    public var color: Color
    public var width: CGFloat
    public var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: width)
            )
    }
}

public struct SplitShadowModifier: ViewModifier {
    public var offset: CGFloat
    public var color: Color
    public var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
                    .offset(x: offset, y: offset)
            )
    }
}

public extension View {
    /// Applies the opaque paper surface color.
    func splitSurface(
        _ color: Color = SplitColors.paper,
        cornerRadius: CGFloat = SplitSpacing.cornerRadius
    ) -> some View {
        modifier(SplitSurfaceModifier(backgroundColor: color, cornerRadius: cornerRadius))
    }

    /// Applies the crisp neo-brutalist stroke outline.
    func splitBorder(
        _ color: Color = SplitColors.ink,
        width: CGFloat = SplitSpacing.borderWidth,
        cornerRadius: CGFloat = SplitSpacing.cornerRadius
    ) -> some View {
        modifier(SplitBorderModifier(color: color, width: width, cornerRadius: cornerRadius))
    }

    /// Applies the signature hard offset shadow without blur.
    func splitShadow(
        offset: CGFloat = SplitSpacing.shadowOffset,
        color: Color = SplitColors.ink,
        cornerRadius: CGFloat = SplitSpacing.cornerRadius
    ) -> some View {
        modifier(SplitShadowModifier(offset: offset, color: color, cornerRadius: cornerRadius))
    }

    /// Convenience modifier combining surface, border, and hard shadow.
    func splitCardStyle(
        surfaceColor: Color = SplitColors.paper,
        borderColor: Color = SplitColors.ink,
        borderWidth: CGFloat = SplitSpacing.borderWidth,
        shadowOffset: CGFloat = SplitSpacing.shadowOffset,
        shadowColor: Color = SplitColors.ink,
        cornerRadius: CGFloat = SplitSpacing.cornerRadius
    ) -> some View {
        self
            .splitSurface(surfaceColor, cornerRadius: cornerRadius)
            .splitBorder(borderColor, width: borderWidth, cornerRadius: cornerRadius)
            .splitShadow(offset: shadowOffset, color: shadowColor, cornerRadius: cornerRadius)
    }
}

/// A button style that physically depresses toward its hard shadow upon touch.
public struct SplitPressableButtonStyle: ButtonStyle {
    public var backgroundColor: Color
    public var foregroundColor: Color
    public var borderColor: Color
    public var shadowOffset: CGFloat
    public var cornerRadius: CGFloat

    public init(
        backgroundColor: Color = SplitColors.green,
        foregroundColor: Color = SplitColors.white,
        borderColor: Color = SplitColors.ink,
        shadowOffset: CGFloat = SplitSpacing.shadowOffset,
        cornerRadius: CGFloat = SplitSpacing.cornerRadius
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.shadowOffset = shadowOffset
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let currentOffset = isPressed ? shadowOffset / 2 : 0
        let effectiveShadow = isPressed ? shadowOffset / 2 : shadowOffset

        return configuration.label
            .foregroundColor(foregroundColor)
            .padding(.horizontal, SplitSpacing.lg)
            .padding(.vertical, SplitSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: SplitSpacing.borderWidth)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(borderColor)
                    .offset(x: effectiveShadow, y: effectiveShadow)
            )
            .offset(x: currentOffset, y: currentOffset)
            .animation(SplitMotion.quick, value: isPressed)
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    SplitHaptics.impact(.light)
                }
            }
    }
}
