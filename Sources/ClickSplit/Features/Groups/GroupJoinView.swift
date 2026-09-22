import SwiftUI

/// Modal sheet for previewing and joining a group via invite link or code.
public struct GroupJoinView: View {
    public var prefilledGroupId: UUID?
    public var onJoined: (SplitGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var inputCode: String = ""
    @State private var resolvedGroup: SplitGroup?
    @State private var isResolving = false
    @State private var isJoining = false
    @State private var errorMessage: String?

    public init(
        prefilledGroupId: UUID? = nil,
        onJoined: @escaping (SplitGroup) -> Void
    ) {
        self.prefilledGroupId = prefilledGroupId
        self.onJoined = onJoined
        if let id = prefilledGroupId {
            self._inputCode = State(initialValue: id.uuidString)
        }
    }

    private var currentUserId: UUID {
        environment.sessionStore.currentUser?.id ?? UUID()
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: SplitSpacing.xs) {
                    Text("JOIN A GROUP")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)
                        .tracking(1)

                    Text("Enter an invite code or link from a friend to start splitting.")
                        .font(SplitTypography.body)
                        .foregroundColor(SplitColors.inkSoft)
                }

                // Input box
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("INVITE LINK OR CODE")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)

                    HStack {
                        TextField("Paste code or link...", text: $inputCode)
                            .font(SplitTypography.body)
                            .autocorrectionDisabled()
                            #if canImport(UIKit)
                            .textInputAutocapitalization(.never)
                            #endif

                        if !inputCode.isEmpty {
                            Button(action: {
                                inputCode = ""
                                resolvedGroup = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(SplitColors.grey)
                            }
                        }
                    }
                    .padding(SplitSpacing.md)
                    .background(SplitColors.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                    )
                }

                // Group Preview Card (if resolved)
                if let group = resolvedGroup {
                    HStack(spacing: SplitSpacing.md) {
                        Text(group.icon ?? "👥")
                            .font(.system(size: 32))
                            .frame(width: 52, height: 52)
                            .background(SplitColors.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: 1.5)
                            )

                        VStack(alignment: .leading, spacing: SplitSpacing.xxs) {
                            Text(group.name)
                                .font(SplitTypography.button)
                                .foregroundColor(SplitColors.ink)

                            Text("Ready to join")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.green)
                        }

                        Spacer()
                    }
                    .padding(SplitSpacing.lg)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.red)
                }

                Spacer()

                // Join Button
                if resolvedGroup != nil {
                    SplitButton("Join Group", icon: "checkmark", variant: .primary, isLoading: isJoining) {
                        executeJoin()
                    }
                } else {
                    SplitButton("Find Group", icon: "magnifyingglass", variant: .secondary, isLoading: isResolving) {
                        resolveGroup()
                    }
                    .disabled(inputCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(SplitSpacing.xl)
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Join Group")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
            .task {
                if prefilledGroupId != nil {
                    resolveGroup()
                }
            }
        }
    }

    private func extractGroupId() -> UUID? {
        let clean = inputCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = UUID(uuidString: clean) {
            return direct
        }
        if let url = URL(string: clean), let last = url.pathComponents.last, let parsed = UUID(uuidString: last) {
            return parsed
        }
        return nil
    }

    private func resolveGroup() {
        guard let id = extractGroupId() else {
            errorMessage = "Invalid group link or code format."
            return
        }

        isResolving = true
        errorMessage = nil

        Task {
            do {
                if let found = try await environment.groupRepository.fetchGroup(id: id) {
                    self.resolvedGroup = found
                    isResolving = false
                } else {
                    self.errorMessage = "Group not found. Please check the invite code."
                    isResolving = false
                }
            } catch {
                self.errorMessage = error.localizedDescription
                isResolving = false
            }
        }
    }

    private func executeJoin() {
        guard let group = resolvedGroup else { return }
        isJoining = true
        errorMessage = nil

        Task {
            do {
                try await environment.groupRepository.joinGroup(groupId: group.id, userId: currentUserId)
                isJoining = false
                SplitHaptics.notify(.success)
                onJoined(group)
                dismiss()
            } catch {
                isJoining = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }
}
