import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Helper for launching external peer-to-peer payment rails (Venmo, Cash App, PayPal, Zelle).
public enum PaymentRailLauncher {
    /// Builds the deep link or web fallback URL for the given payment rail.
    public static func generatePaymentURL(
        method: SettlementMethod,
        recipientHandle: String? = nil,
        amount: Decimal,
        note: String = "Click Split Settlement"
    ) -> URL? {
        let cleanHandle = recipientHandle?.trimmingCharacters(in: CharacterSet(charactersIn: "@$ ")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedNote = note.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let amountString = String(describing: amount)

        switch method {
        case .venmo:
            if !cleanHandle.isEmpty {
                return URL(string: "venmo://paycharge?txn=pay&recipients=\(cleanHandle)&amount=\(amountString)&note=\(encodedNote)")
            }
            return URL(string: "https://venmo.com")

        case .cashApp:
            if !cleanHandle.isEmpty {
                return URL(string: "https://cash.app/$\(cleanHandle)/\(amountString)")
            }
            return URL(string: "https://cash.app")

        case .paypal:
            if !cleanHandle.isEmpty {
                return URL(string: "https://paypal.me/\(cleanHandle)/\(amountString)")
            }
            return URL(string: "https://paypal.com")

        case .zelle, .cash, .other:
            return nil
        }
    }

    /// Launches the chosen external payment app or web fallback with prefilled amount.
    @MainActor
    public static func openPaymentRail(
        method: SettlementMethod,
        recipientHandle: String? = nil,
        amount: Decimal,
        note: String = "Click Split Settlement"
    ) {
        var urlToOpen = generatePaymentURL(method: method, recipientHandle: recipientHandle, amount: amount, note: note)

        if method == .venmo && !canOpen(urlToOpen) {
            urlToOpen = URL(string: "https://venmo.com")
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
