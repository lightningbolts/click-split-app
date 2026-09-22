import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

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

    /// Adds a native "Done" keyboard toolbar button to dismiss number pads and input views.
    @ViewBuilder
    func splitKeyboardDoneButton() -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(SplitTypography.buttonSmall)
                .foregroundColor(SplitColors.ink)
            }
        }
        #else
        self
        #endif
    }

    /// Dismisses active keyboard when tapping background regions.
    func splitDismissKeyboardOnTap() -> some View {
        #if os(iOS)
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        #else
        self
        #endif
    }
}
