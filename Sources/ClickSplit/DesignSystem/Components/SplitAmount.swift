import SwiftUI

/// Formatted monetary amount display with monospaced tabular figures and financial color semantics.
public struct SplitAmount: View {
    public enum Style {
        case hero
        case large
        case medium
        case small
    }

    public var amount: Decimal
    public var currencySymbol: String
    public var style: Style
    public var showSign: Bool
    public var forceColor: Color?

    public init(
        _ amount: Decimal,
        currencySymbol: String = "$",
        style: Style = .medium,
        showSign: Bool = false,
        color: Color? = nil
    ) {
        self.amount = amount
        self.currencySymbol = currencySymbol
        self.style = style
        self.showSign = showSign
        self.forceColor = color
    }

    private var font: Font {
        switch style {
        case .hero: return SplitTypography.amountHero
        case .large: return SplitTypography.amountLarge
        case .medium: return SplitTypography.amountMedium
        case .small: return SplitTypography.amountSmall
        }
    }

    private var color: Color {
        if let forceColor {
            return forceColor
        }
        if showSign {
            if amount > 0 { return SplitColors.green }
            if amount < 0 { return SplitColors.red }
        }
        return SplitColors.ink
    }

    private var formattedText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let absoluteAmount = NSDecimalNumber(decimal: abs(amount))
        let formattedNumber = formatter.string(from: absoluteAmount) ?? "\(currencySymbol)\(abs(amount))"

        if showSign {
            if amount > 0 {
                return "+\(formattedNumber)"
            } else if amount < 0 {
                return "-\(formattedNumber)"
            }
        }
        return formattedNumber
    }

    public var body: some View {
        Text(formattedText)
            .font(font)
            .foregroundColor(color)
            .splitMonospacedDigits()
    }
}
