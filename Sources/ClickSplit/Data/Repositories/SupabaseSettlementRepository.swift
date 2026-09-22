import Foundation

/// Live Supabase implementation of SettlementRepositoryProtocol.
public final class SupabaseSettlementRepository: SettlementRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient
    private let sessionStore: SessionStore

    public init(client: SupabaseClient = SupabaseClient(), sessionStore: SessionStore) {
        self.client = client
        self.sessionStore = sessionStore
    }

    private var token: String? {
        sessionStore.authToken
    }

    public func fetchSettlements(groupId: UUID) async throws -> [SplitSettlement] {
        return try await client.fetch(
            table: "split_settlements",
            filters: [
                URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)"),
                URLQueryItem(name: "order", value: "settled_at.desc")
            ],
            authToken: token
        )
    }

    public func recordSettlement(
        groupId: UUID,
        fromUser: UUID,
        toUser: UUID,
        amount: Decimal,
        method: SettlementMethod?
    ) async throws -> SplitSettlement {
        struct InsertSettlementPayload: Encodable {
            let group_id: UUID
            let from_user: UUID
            let to_user: UUID
            let amount: Decimal
            let method: String?
        }

        let payload = InsertSettlementPayload(
            group_id: groupId,
            from_user: fromUser,
            to_user: toUser,
            amount: amount,
            method: method?.rawValue
        )

        let inserted: [SplitSettlement] = try await client.insert(
            table: "split_settlements",
            value: payload,
            authToken: token
        )

        guard let settlement = inserted.first else {
            throw SupabaseClient.SupabaseError.httpError(statusCode: 500, message: "Settlement insert failed")
        }

        return settlement
    }
}
