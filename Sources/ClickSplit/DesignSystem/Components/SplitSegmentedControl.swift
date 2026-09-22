import SwiftUI

/// Branded neo-brutalist segmented control for selecting options (e.g. SplitMethod).
public struct SplitSegmentedControl<T: Hashable & CustomStringConvertible>: View {
    public var options: [T]
    @Binding public var selection: T

    public init(options: [T], selection: Binding<T>) {
        self.options = options
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option

                Button(action: {
                    SplitHaptics.selection()
                    withAnimation(SplitMotion.quick) {
                        selection = option
                    }
                }) {
                    Text(option.description)
                        .font(SplitTypography.buttonSmall)
                        .foregroundColor(isSelected ? SplitColors.white : SplitColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplitSpacing.sm)
                        .background(isSelected ? SplitColors.ink : Color.clear)
                }
                .buttonStyle(.plain)

                if option != options.last {
                    Divider()
                        .frame(width: SplitSpacing.borderWidth)
                        .overlay(SplitColors.ink)
                }
            }
        }
        .background(SplitColors.paper)
        .overlay(
            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius))
        .background(
            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                .fill(SplitColors.ink)
                .offset(x: SplitSpacing.shadowOffsetSmall, y: SplitSpacing.shadowOffsetSmall)
        )
    }
}
