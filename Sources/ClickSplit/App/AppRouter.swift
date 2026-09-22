import SwiftUI
import Observation

/// Global router handling universal links and deep link navigation.
@Observable
public final class AppRouter: @unchecked Sendable {
    public var presentedJoinGroupId: UUID?
    public var showJoinGroupSheet: Bool = false

    public init() {}

    /// Parses incoming Universal Link or deep link URL.
    /// Format: `https://clickplatforms.com/group/<uuid>` or `clicksplit://group/<uuid>`
    public func handleIncomingURL(_ url: URL) {
        let components = url.pathComponents
        if let groupIndex = components.firstIndex(of: "group"),
           groupIndex + 1 < components.count,
           let id = UUID(uuidString: components[groupIndex + 1]) {
            self.presentedJoinGroupId = id
            self.showJoinGroupSheet = true
            SplitHaptics.impact(.medium)
        }
    }
}

// SwiftUI Environment Key
private struct AppRouterKey: EnvironmentKey {
    static let defaultValue = AppRouter()
}

public extension EnvironmentValues {
    var appRouter: AppRouter {
        get { self[AppRouterKey.self] }
        set { self[AppRouterKey.self] = newValue }
    }
}
