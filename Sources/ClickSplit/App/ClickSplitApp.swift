import SwiftUI

#if canImport(UIKit)
@main
public struct ClickSplitApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            ClickSplitRootView()
        }
    }
}
#endif
