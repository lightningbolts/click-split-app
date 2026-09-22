import Foundation

/// Lightweight, dependency-free native Supabase HTTP client for iOS.
/// Direct implementation over URLSession supporting PostgREST queries, RPCs, and Auth.
public final class SupabaseClient: Sendable {
    public let supabaseURL: URL
    public let anonKey: String
    private let session: URLSession

    public init(
        supabaseURL: URL = SupabaseConfig.defaultURL,
        anonKey: String = SupabaseConfig.defaultAnonKey,
        session: URLSession = .shared
    ) {
        self.supabaseURL = supabaseURL
        self.anonKey = anonKey
        self.session = session
    }

    public enum SupabaseError: LocalizedError {
        case invalidURL
        case httpError(statusCode: Int, message: String)
        case decodingError(Error)
        case unauthenticated

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Supabase endpoint URL."
            case .httpError(let statusCode, let message):
                return "Supabase HTTP error \(statusCode): \(message)"
            case .decodingError(let err):
                return "Failed to parse Supabase response: \(err.localizedDescription)"
            case .unauthenticated:
                return "User is not authenticated."
            }
        }
    }

    // ────────────────── Headers ──────────────────

    private func makeHeaders(authToken: String?) -> [String: String] {
        var headers = [
            "apikey": anonKey,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        if let token = authToken, !token.isEmpty {
            headers["Authorization"] = "Bearer \(token)"
        } else {
            headers["Authorization"] = "Bearer \(anonKey)"
        }
        return headers
    }

    // ────────────────── PostgREST Queries ──────────────────

    /// Fetches records from a table with optional filter query items.
    public func fetch<T: Decodable>(
        table: String,
        select: String = "*",
        filters: [URLQueryItem] = [],
        authToken: String? = nil
    ) async throws -> [T] {
        guard var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false) else {
            throw SupabaseError.invalidURL
        }

        var queryItems = [URLQueryItem(name: "select", value: select)]
        queryItems.append(contentsOf: filters)
        components.queryItems = queryItems

        guard let requestURL = components.url else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        for (key, value) in makeHeaders(authToken: authToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([T].self, from: data)
    }

    /// Inserts records into a table and returns the inserted records.
    public func insert<T: Encodable, R: Decodable>(
        table: String,
        value: T,
        authToken: String? = nil
    ) async throws -> [R] {
        let endpoint = supabaseURL.appendingPathComponent("rest/v1/\(table)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        for (key, value) in makeHeaders(authToken: authToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(value)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([R].self, from: data)
    }

    /// Deletes records matching the given query filters.
    public func delete(
        table: String,
        filters: [URLQueryItem],
        authToken: String? = nil
    ) async throws {
        guard var components = URLComponents(url: supabaseURL.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false) else {
            throw SupabaseError.invalidURL
        }
        components.queryItems = filters

        guard let requestURL = components.url else {
            throw SupabaseError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "DELETE"
        for (key, value) in makeHeaders(authToken: authToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    // ────────────────── RPC Execution ──────────────────

    /// Calls a PostgreSQL RPC stored function.
    public func rpc<P: Encodable, R: Decodable>(
        name: String,
        params: P,
        authToken: String? = nil
    ) async throws -> R {
        let endpoint = supabaseURL.appendingPathComponent("rest/v1/rpc/\(name)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        for (key, value) in makeHeaders(authToken: authToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(params)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(R.self, from: data)
    }

    // ────────────────── Auth ──────────────────

    /// Authenticates with an Apple or Google OpenID Connect identity token.
    public func signInWithIdToken(
        provider: String,
        idToken: String,
        nonce: String? = nil
    ) async throws -> AuthResponse {
        let endpoint = supabaseURL.appendingPathComponent("auth/v1/token")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        for (key, value) in makeHeaders(authToken: nil) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        var queryComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        queryComponents?.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        request.url = queryComponents?.url

        struct TokenPayload: Encodable {
            let provider: String
            let id_token: String
            let nonce: String?
        }

        let payload = TokenPayload(provider: provider, id_token: idToken, nonce: nonce)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    /// Fetches the authenticated user profile from Supabase Auth.
    public func getUser(authToken: String) async throws -> AuthUser {
        let endpoint = supabaseURL.appendingPathComponent("auth/v1/user")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        for (key, value) in makeHeaders(authToken: authToken) {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthUser.self, from: data)
    }

    /// Constructs the OAuth authorization URL for the specified provider (e.g. "google").
    public func makeOAuthURL(provider: String, redirectTo: String = "click://login") -> URL? {
        guard var components = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirectTo),
            URLQueryItem(name: "scopes", value: "openid profile email")
        ]
        return components.url
    }

    /// Exchanges an OAuth PKCE / authorization code for user session tokens.
    public func exchangeCodeForSession(code: String) async throws -> AuthResponse {
        let endpoint = supabaseURL.appendingPathComponent("auth/v1/token")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "authorization_code")]
        guard let url = components?.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in makeHeaders(authToken: nil) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let body = ["auth_code": code, "code": code]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthResponse.self, from: data)
    }


    // ────────────────── Response Validator ──────────────────

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
}

/// Supabase Auth response container.
public struct AuthResponse: Codable, Sendable {
    public let access_token: String
    public let token_type: String
    public let expires_in: Int
    public let refresh_token: String
    public let user: AuthUser
}

public struct AuthUser: Codable, Sendable {
    public let id: UUID
    public let email: String?
    public let rawMetadata: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case rawMetadata = "user_metadata"
    }

    public var fullName: String? {
        rawMetadata?["full_name"]?.stringValue
            ?? rawMetadata?["name"]?.stringValue
    }

    public var avatarUrl: String? {
        rawMetadata?["avatar_url"]?.stringValue
            ?? rawMetadata?["picture"]?.stringValue
    }
}

public enum AnyCodableValue: Codable, Sendable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case other

    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        default: return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else {
            self = .other
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .bool(let b): try container.encode(b)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .other: try container.encodeNil()
        }
    }
}
