import SwiftUI

/// Categorized group icon picker providing 1:1 parity with the Click Split web app.
public struct GroupIconPicker: View {
    @Binding public var selectedIcon: String

    @State private var selectedCategory: String = "All"
    @State private var customEmojiText: String = ""

    public static let categories: [String: [String]] = [
        "Living": ["🏠", "🏢", "🛋️", "🛏️", "🧹", "📦", "🪴", "🐶", "🐱", "🔑", "🚪", "🧺", "🛁"],
        "Travel": ["✈️", "🚗", "🚆", "🏖️", "🏕️", "🏔️", "🗺️", "🚢", "⛽", "🏨", "🚕", "🧳", "🌴"],
        "Food": ["🍕", "🍔", "🍣", "🌮", "🍜", "☕", "🍻", "🍷", "🛒", "🍩", "🥐", "🍦", "🥑"],
        "Fun": ["🎉", "🎬", "🎮", "🎳", "🎟️", "⚽", "🏋️", "🎤", "🎁", "🎲", "🎸", "🎨", "🎯"],
        "Bills": ["💡", "📱", "💻", "🛠️", "💼", "🎓", "📚", "🧾", "💸", "⚡", "💧", "📶", "🔥"]
    ]

    public static let categoryOrder = ["All", "Living", "Travel", "Food", "Fun", "Bills"]

    private var displayedEmojis: [String] {
        if selectedCategory == "All" {
            return Self.categoryOrder
                .filter { $0 != "All" }
                .compactMap { Self.categories[$0] }
                .flatMap { $0 }
        } else {
            return Self.categories[selectedCategory] ?? []
        }
    }

    public init(selectedIcon: Binding<String>) {
        self._selectedIcon = selectedIcon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplitSpacing.sm) {
            // Header Row: Label + Selected Indicator Preview
            HStack(alignment: .center) {
                Text("CHOOSE ICON")
                    .font(SplitTypography.badge)
                    .foregroundColor(SplitColors.inkSoft)
                    .tracking(1)

                Spacer()

                HStack(spacing: 6) {
                    Text("Selected:")
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.inkSoft)

                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(SplitColors.greenDim)
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(SplitColors.ink, lineWidth: 2)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(SplitColors.ink)
                                    .offset(x: 1.5, y: 1.5)
                            )

                        Text(selectedIcon)
                            .font(.system(size: 18))
                    }
                }
            }

            // Category Filter Pills (Horizontal Scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplitSpacing.xs) {
                    ForEach(Self.categoryOrder, id: \.self) { cat in
                        let isSelected = selectedCategory == cat
                        Button {
                            SplitHaptics.selection()
                            selectedCategory = cat
                        } label: {
                            Text(cat)
                                .font(SplitTypography.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(isSelected ? SplitColors.ink : SplitColors.paper)
                                .foregroundColor(isSelected ? SplitColors.white : SplitColors.ink)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(SplitColors.ink, lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            // Scrollable Emoji Grid
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 42), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(displayedEmojis, id: \.self) { emoji in
                        let isSelected = selectedIcon == emoji
                        Button {
                            SplitHaptics.selection()
                            selectedIcon = emoji
                            customEmojiText = ""
                        } label: {
                            Text(emoji)
                                .font(.system(size: 20))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(isSelected ? SplitColors.greenDim : SplitColors.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(
                                            isSelected ? SplitColors.ink : SplitColors.grey.opacity(0.4),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                )
                                .background(
                                    isSelected
                                        ? RoundedRectangle(cornerRadius: 2)
                                            .fill(SplitColors.ink)
                                            .offset(x: 1.5, y: 1.5)
                                        : nil
                                )
                                .scaleEffect(isSelected ? 1.05 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 160)
            .background(SplitColors.paperDim)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(SplitColors.ink, lineWidth: 2)
            )

            // Custom Emoji Input Row
            HStack(spacing: SplitSpacing.sm) {
                Text("Or enter custom emoji:")
                    .font(SplitTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(SplitColors.inkSoft)

                TextField("e.g. 🏄 or ⚡", text: $customEmojiText)
                    .font(SplitTypography.body)
                    .padding(.horizontal, SplitSpacing.sm)
                    .padding(.vertical, 6)
                    .background(SplitColors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(SplitColors.ink, lineWidth: 1.5)
                    )
                    .frame(width: 130)
                    .onChange(of: customEmojiText) { _, newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let firstCharacter = trimmed.first {
                            selectedIcon = String(firstCharacter)
                        }
                    }
            }
            .padding(.top, 4)
        }
    }
}
