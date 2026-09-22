import SwiftUI

/// Reusable user avatar view matching the Click neo-brutalist design system.
/// Displays the user's remote profile image when available with async loading,
/// crisp neo-brutalist ink borders, and smooth fallback to bold user initials.
public struct UserAvatarView: View {
    public enum Shape {
        case circle
        case roundedSquare
    }

    public var avatarUrl: String?
    public var name: String?
    public var size: CGFloat
    public var shape: Shape
    public var showBorder: Bool
    public var showShadow: Bool

    public init(
        avatarUrl: String?,
        name: String? = nil,
        size: CGFloat = 36,
        shape: Shape = .circle,
        showBorder: Bool = true,
        showShadow: Bool = false
    ) {
        self.avatarUrl = avatarUrl
        self.name = name
        self.size = size
        self.shape = shape
        self.showBorder = showBorder
        self.showShadow = showShadow
    }

    private var initials: String {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "CS"
        }
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "CS" : letters.uppercased()
    }

    private var borderWidth: CGFloat {
        max(1.5, size * 0.035)
    }

    private var cornerRadius: CGFloat {
        switch shape {
        case .circle:
            return size / 2.0
        case .roundedSquare:
            return max(3.0, size * 0.18)
        }
    }

    private var validURL: URL? {
        guard let avatarUrl = avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              !avatarUrl.isEmpty else { return nil }
        return URL(string: avatarUrl)
    }

    public var body: some View {
        ZStack {
            if let validURL {
                AsyncImage(url: validURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                    case .failure:
                        initialsFallback

                    case .empty:
                        ZStack {
                            initialsFallback
                            ProgressView()
                                .scaleEffect(size < 40 ? 0.6 : 0.9)
                        }

                    @unknown default:
                        initialsFallback
                    }
                }
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Group {
                if showBorder {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(SplitColors.ink, lineWidth: borderWidth)
                }
            }
        )
        .background(
            Group {
                if showShadow {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(SplitColors.ink)
                        .offset(x: max(2.0, size * 0.05), y: max(2.0, size * 0.05))
                }
            }
        )
    }

    private var initialsFallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(SplitColors.greenDim)

            Text(initials)
                .font(.system(size: max(9.0, size * 0.38), weight: .black, design: .rounded))
                .foregroundColor(SplitColors.green)
        }
        .frame(width: size, height: size)
    }
}
