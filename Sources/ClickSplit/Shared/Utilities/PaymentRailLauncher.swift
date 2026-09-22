import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Helper for launching external peer-to-peer payment rails (Venmo, Cash App, PayPal, Zelle).
public enum PaymentRailLauncher {
    /// Launches the chosen external payment app or web fallback with prefilled amount.
    public static func openPaymentRail(
        method: SettlementMethod,
        recipientHandle: String? = nil,
        amount: Decimal,
        note: String = "Click Split Settlement"
    ) {
        let cleanHandle = recipientHandle?.trimmingCharacters(in: CharacterSet(charactersIn: "@$ ")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let amountString = String(describing: amount)

        var urlToOpen: URL?

        switch method {
        case .venmo:
            if !cleanHandle.isEmpty {
                urlToOpen = URL(string: "venmo://paycharge?txn=pay&recipients=\(cleanHandle)&amount=\(amountString)&note=\(encodedNote)")
            }
            if urlToOpen == nil || !canOpen(urlToOpen) {
                urlToOpen = URL(string: "https://venmo.com")
            }

        case .cashApp:
            if !cleanHandle.isEmpty {
                urlToOpen = URL(string: "https://cash.app/$\(cleanHandle)/\(amountString)")
            } else {
                urlToOpen = URL(string: "https://cash.app")
            }

        case .paypal:
            if !cleanHandle.isEmpty {
                urlToOpen = URL(string: "https://paypal.me/\(cleanHandle)/\(amountString)")
            } else {
                urlToOpen = URL(string: "https://paypal.com")
            }

        case .zelle, .cash, .other:
            urlToOpen = nil
        }

        #if canImport(UIKit)
        if let url = urlToOpen {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private static func canOpen(_ url: URL?) -> Bool {
        #if canImport(UIKit)
        guard let url else { return false }
        return UIApplication.shared.canOpenURL(url)
        #else
        return false
        #endif
    }
}
