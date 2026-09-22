import Foundation

/// Notification names for Supabase realtime database events.
public enum SplitRealtimeNotification {
    public static let dataChanged = Notification.Name("SplitRealtimeNotification.dataChanged")
}

/// Lightweight WebSocket client for Supabase Realtime Postgres change subscriptions.
public final class SupabaseRealtimeClient: @unchecked Sendable {
    private let websocketURL: URL
    private let anonKey: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var heartbeatTimer: Task<Void, Never>?

    public init(
        supabaseURL: URL = SupabaseConfig.defaultURL,
        anonKey: String = SupabaseConfig.defaultAnonKey
    ) {
        self.anonKey = anonKey
        var components = URLComponents(url: supabaseURL, resolvingAgainstBaseURL: false)
        let isSecure = components?.scheme == "https"
        components?.scheme = isSecure ? "wss" : "ws"
        components?.path = "/realtime/v1/websocket"
        components?.queryItems = [
            URLQueryItem(name: "apikey", value: anonKey),
            URLQueryItem(name: "vsn", value: "1.0.0")
        ]
        self.websocketURL = components?.url ?? URL(string: "wss://lrgcwnmcscimkmslihxp.supabase.co/realtime/v1/websocket")!
    }

    /// Connects to Supabase Realtime and subscribes to public table changes.
    public func connect(authToken: String? = nil) {
        guard !isConnected else { return }

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: websocketURL)
        self.webSocketTask = task
        self.isConnected = true
        task.resume()

        joinChannels(authToken: authToken)
        startListening()
        startHeartbeat()
    }

    /// Reconnects with the latest authenticated token after sign-in/session restoration.
    public func reconnect(authToken: String?) {
        disconnect()
        connect(authToken: authToken)
    }

    /// Disconnects the realtime socket.
    public func disconnect() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func joinChannels(authToken: String?) {
        let token = authToken ?? anonKey
        let joinMessage: [String: Any] = [
            "topic": "realtime:public",
            "event": "phx_join",
            "payload": [
                "config": [
                    "broadcast": ["self": true],
                    "postgres_changes": [
                        ["event": "*", "schema": "public", "table": "split_expenses"],
                        ["event": "*", "schema": "public", "table": "split_expense_items"],
                        ["event": "*", "schema": "public", "table": "split_expense_shares"],
                        ["event": "*", "schema": "public", "table": "split_settlements"],
                        ["event": "*", "schema": "public", "table": "split_group_members"]
                    ]
                ],
                "access_token": token
            ],
            "ref": "1"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: joinMessage),
           let string = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(string)) { _ in }
        }
    }

    private func startListening() {
        guard isConnected else { return }

        webSocketTask?.receive { [weak self] result in
            guard let self = self, self.isConnected else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleIncomingMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleIncomingMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening loop
                self.startListening()

            case .failure:
                self.isConnected = false
            }
        }
    }

    private func handleIncomingMessage(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            payload["event"] as? String == "postgres_changes"
        else {
            return
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: SplitRealtimeNotification.dataChanged, object: nil)
        }
    }

    private func startHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard let self = self, self.isConnected else { break }
                let heartbeat: [String: Any] = [
                    "topic": "phoenix",
                    "event": "heartbeat",
                    "payload": [:],
                    "ref": UUID().uuidString
                ]
                if let data = try? JSONSerialization.data(withJSONObject: heartbeat),
                   let string = String(data: data, encoding: .utf8) {
                    self.webSocketTask?.send(.string(string)) { _ in }
                }
            }
        }
    }
}
