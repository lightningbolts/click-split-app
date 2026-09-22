import Foundation

/// Live Supabase implementation of GroupRepositoryProtocol.
public final class SupabaseGroupRepository: GroupRepositoryProtocol, @unchecked Sendable {
    private let client: SupabaseClient
    private let sessionStore: SessionStore

    public init(client: SupabaseClient = SupabaseClient(), sessionStore: SessionStore) {
        self.client = client
        self.sessionStore = sessionStore
    }

    private var token: String? {
        sessionStore.authToken
    }

    public func fetchUserGroups(userId: UUID) async throws -> [SplitGroup] {
        // Query memberships for user
        let members: [SplitGroupMember] = try await client.fetch(
            table: "split_group_members",
            filters: [URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)")],
            authToken: token
        )
        guard !members.isEmpty else { return [] }

        let groupIds = members.map { $0.groupId.uuidString }.joined(separator: ",")
        return try await client.fetch(
            table: "split_groups",
            filters: [URLQueryItem(name: "id", value: "in.(\(groupIds))")],
            authToken: token
        )
    }

    public func fetchGroup(id: UUID) async throws -> SplitGroup? {
        let groups: [SplitGroup] = try await client.fetch(
            table: "split_groups",
            filters: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            authToken: token
        )
        return groups.first
    }

    public func fetchGroupMembers(groupId: UUID) async throws -> [SplitGroupMember] {
        let memberships: [SplitGroupMember] = try await client.fetch(
            table: "split_group_members",
            filters: [URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)")],
            authToken: token
        )

        guard !memberships.isEmpty else { return [] }

        let userIds = memberships.map { $0.userId.uuidString.lowercased() }.joined(separator: ",")
        let profiles: [PublicUserRow] = (try? await client.fetch(
            table: "users",
            select: "id,name,image,email",
            filters: [URLQueryItem(name: "id", value: "in.(\(userIds))")],
            authToken: token
        )) ?? []
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        return memberships.map { membership in
            var hydrated = membership
            if let row = profileMap[membership.userId] {
                hydrated.profile = SplitUserProfile(
                    id: row.id,
                    email: row.email,
                    fullName: row.name,
                    avatarUrl: row.image
                )
            }
            return hydrated
        }
    }

    public func createGroup(name: String, icon: String?, createdBy: UUID) async throws -> SplitGroup {
        struct InsertGroupPayload: Encodable {
            let name: String
            let icon: String?
            let created_by: UUID
        }
        let payload = InsertGroupPayload(name: name, icon: icon, created_by: createdBy)
        let inserted: [SplitGroup] = try await client.insert(
            table: "split_groups",
            value: payload,
            authToken: token
        )
        guard let group = inserted.first else {
            throw SupabaseClient.SupabaseError.httpError(statusCode: 500, message: "Group creation failed")
        }

        // Add creator as member
        try await joinGroup(groupId: group.id, userId: createdBy)
        return group
    }

    public func joinGroup(groupId: UUID, userId: UUID) async throws {
        struct InsertMemberPayload: Encodable {
            let group_id: UUID
            let user_id: UUID
        }
        let payload = InsertMemberPayload(group_id: groupId, user_id: userId)
        let _: [SplitGroupMember] = try await client.insert(
            table: "split_group_members",
            value: payload,
            authToken: token
        )
    }

    public func addGroupMember(groupId: UUID, email: String) async throws {
        let currentUserId = try await requireGroupCreator(groupId: groupId)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail.contains("@"), normalizedEmail.count <= 254 else {
            throw GroupMemberManagementError.invalidEmail
        }

        let profiles: [PublicUserRow] = try await client.fetch(
            table: "users",
            select: "id,name,image,email",
            filters: [URLQueryItem(name: "email", value: "eq.\(normalizedEmail)")],
            authToken: token
        )
        guard let profile = profiles.first else {
            throw GroupMemberManagementError.userNotFound
        }

        let existing: [SplitGroupMember] = try await client.fetch(
            table: "split_group_members",
            filters: [
                URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(profile.id.uuidString)")
            ],
            authToken: token
        )
        guard existing.isEmpty else {
            throw GroupMemberManagementError.alreadyMember
        }

        struct InsertMemberPayload: Encodable {
            let group_id: UUID
            let user_id: UUID
        }
        let payload = InsertMemberPayload(group_id: groupId, user_id: profile.id)
        let _: [SplitGroupMember] = try await client.insert(
            table: "split_group_members",
            value: payload,
            authToken: token
        )
    }

    public func removeGroupMember(groupId: UUID, userId: UUID) async throws {
        let currentUserId = try await requireGroupCreator(groupId: groupId)
        guard userId != currentUserId else {
            throw GroupMemberManagementError.creatorCannotBeRemoved
        }

        let existing: [SplitGroupMember] = try await client.fetch(
            table: "split_group_members",
            filters: [
                URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)")
            ],
            authToken: token
        )
        guard !existing.isEmpty else {
            throw GroupMemberManagementError.memberNotFound
        }

        let balance = try await fetchGroupBalance(groupId: groupId, userId: userId)
        guard balance > Decimal(string: "-0.01")! && balance < Decimal(string: "0.01")! else {
            throw GroupMemberManagementError.unsettledBalance
        }

        try await client.delete(
            table: "split_group_members",
            filters: [
                URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)")
            ],
            authToken: token
        )
    }

    private func requireGroupCreator(groupId: UUID) async throws -> UUID {
        guard let currentUserId = sessionStore.currentUser?.id else {
            throw SupabaseClient.SupabaseError.unauthenticated
        }
        guard let group = try await fetchGroup(id: groupId), group.createdBy == currentUserId else {
            throw GroupMemberManagementError.notCreator
        }
        return currentUserId
    }

    public func leaveGroup(groupId: UUID, userId: UUID) async throws {
        try await client.delete(
            table: "split_group_members",
            filters: [
                URLQueryItem(name: "group_id", value: "eq.\(groupId.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)")
            ],
            authToken: token
        )
    }

    public func deleteGroup(groupId: UUID) async throws {
        try await client.delete(
            table: "split_groups",
            filters: [URLQueryItem(name: "id", value: "eq.\(groupId.uuidString)")],
            authToken: token
        )
    }

    public func fetchGroupBalance(groupId: UUID, userId: UUID) async throws -> Decimal {
        struct BalanceParams: Encodable {
            let p_group_id: UUID
            let p_user_id: UUID
        }
        let params = BalanceParams(p_group_id: groupId, p_user_id: userId)
        let balance: Decimal = try await client.rpc(
            name: "calculate_split_group_balance",
            params: params,
            authToken: token
        )
        return balance
    }
}
