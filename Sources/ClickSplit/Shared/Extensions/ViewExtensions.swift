import SwiftUI

public extension View {
    /// Applies inline navigation title display mode where supported (iOS/visionOS).
    @ViewBuilder
    func splitInlineTitleDisplayMode() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
