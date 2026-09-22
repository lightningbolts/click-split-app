import SwiftUI

/// Authentic Click Split website brand mark.
/// Faithfully reproduces the neo-brutalist geometric logo mark from the Click Split web app
/// (`.brand .mark` and `.auth-mark` in globals.css):
/// An emerald green surface (#0E9F5A), crisp black ink borders (#141414),
/// a neo-brutalist hard drop shadow, and a concentric inner square frame.
public struct ClickBrandLogo: View {
    public enum Style {
        /// Standard mark with hard drop shadow (matches web sign-in `.auth-mark`)
        case authMark
        /// Full app icon presentation on warm paper background
        case appIcon
        /// Pure mark without drop shadow (matches topbar `.mark`)
        case pureMark
    }

    public var size: CGFloat
    public var style: Style

    public init(size: CGFloat = 64, style: Style = .authMark) {
        self.size = size
        self.style = style
    }

    public var body: some View {
        switch style {
        case .authMark:
            markView(showShadow: true)
                .frame(width: size, height: size)

        case .pureMark:
            markView(showShadow: false)
                .frame(width: size, height: size)

        case .appIcon:
            ZStack {
                // Warm paper background (#FAF8F3)
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(SplitColors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22)
                            .stroke(SplitColors.ink.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

                markView(showShadow: true, markScale: 0.58)
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Neo-brutalist Concentric Mark Geometry

    @ViewBuilder
    private func markView(showShadow: Bool, markScale: CGFloat = 1.0) -> some View {
        let markSize = size * markScale
        let borderWidth = max(2.0, markSize * (2.5 / 52.0))
        let shadowOffset = max(3.0, markSize * (4.0 / 52.0))
        let inset = markSize * (10.0 / 52.0)
        let cornerRadius = max(2.0, markSize * (3.0 / 52.0))

        ZStack {
            // Hard neo-brutalist drop shadow (solid ink, zero blur)
            if showShadow {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(SplitColors.ink)
                    .offset(x: shadowOffset, y: shadowOffset)
            }

            // Outer Emerald Green Square
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(SplitColors.green)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(SplitColors.ink, lineWidth: borderWidth)
                )

            // Concentric Inner Square Frame
            RoundedRectangle(cornerRadius: max(1.5, cornerRadius - 1.0))
                .stroke(SplitColors.ink, lineWidth: borderWidth)
                .padding(inset)
        }
        .frame(width: markSize, height: markSize)
    }
}
