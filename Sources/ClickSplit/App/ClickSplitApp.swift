import SwiftUI

#if canImport(UIKit)
@main
public struct ClickSplitApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            let environment = ProcessInfo.processInfo.arguments.contains("-preview")
                ? AppEnvironment.preview()
                : AppEnvironment.live()
            ClickSplitRootView(environment: environment)
        }
    }
}
#endif
