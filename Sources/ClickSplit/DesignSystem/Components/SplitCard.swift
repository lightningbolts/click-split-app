import SwiftUI

/// Neo-brutalist container card with hard stroke and offset shadow.
public struct SplitCard<Content: View>: View {
    public var surfaceColor: Color
    public var borderColor: Color
    public var shadowColor: Color
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    @ViewBuilder public var content: () -> Content

    public init(
        surfaceColor: Color = SplitColors.paperDim,
        borderColor: Color = SplitColors.ink,
        shadowColor: Color = SplitColors.ink,
        padding: CGFloat = SplitSpacing.lg,
        cornerRadius: CGFloat = SplitSpacing.cornerRadius,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.surfaceColor = surfaceColor
        self.borderColor = borderColor
        self.shadowColor = shadowColor
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .splitCardStyle(
            surfaceColor: surfaceColor,
            borderColor: borderColor,
            shadowColor: shadowColor,
            cornerRadius: cornerRadius
        )
    }
}
