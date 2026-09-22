import SwiftUI

/// Comprehensive native group management and settings sheet.
public struct GroupSettingsSheet: View {
    public var group: SplitGroup
    public var members: [SplitGroupMember]
    public var expenses: [SplitExpense]
    public var onGroupModified: () -> Void
    public var onGroupExited: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var groupName: String
    @State private var selectedIcon: String
    @State private var showLeaveDialog = false
    @State private var showDeleteDialog = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var managedMembers: [SplitGroupMember]
    @State private var memberEmail = ""
    @State private var isAddingMember = false
    @State private var memberPendingRemoval: SplitGroupMember?
    @State private var removingMemberId: UUID?

    public init(
        group: SplitGroup,
        members: [SplitGroupMember],
        expenses: [SplitExpense],
        onGroupModified: @escaping () -> Void,
        onGroupExited: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.expenses = expenses
        self.onGroupModified = onGroupModified
        self.onGroupExited = onGroupExited
        self._groupName = State(initialValue: group.name)
        self._selectedIcon = State(initialValue: group.icon ?? "👥")
        self._managedMembers = State(initialValue: members)
    }

    private var currentUserId: UUID {
        environment.sessionStore.currentUser?.id ?? UUID()
    }

    private var isCreator: Bool {
        group.createdBy == currentUserId
    }

    private var csvExportURL: URL? {
        let csv = CSVExporter.generateCSV(groupName: group.name, expenses: expenses, members: managedMembers)
        return CSVExporter.createTemporaryCSVFile(groupName: group.name, csvString: csv)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                    // Group Identity Section
                    VStack(alignment: .leading, spacing: SplitSpacing.md) {
                        Text("GROUP DETAILS")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)
                            .tracking(1)

                        TextField("Group Name", text: $groupName)
                            .font(SplitTypography.body)
                            .padding(SplitSpacing.md)
                            .background(SplitColors.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                            )

                        GroupIconPicker(selectedIcon: $selectedIcon)
                    }
                    .padding(SplitSpacing.lg)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)

                    // Members List Section
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        HStack {
                            Text("MEMBERS (\(managedMembers.count))")
                                .font(SplitTypography.badge)
                                .foregroundColor(SplitColors.inkSoft)
                                .tracking(1)

                            Spacer()

                            ShareLink(
                                item: SupabaseConfig.defaultServerBaseURL
                                    .appendingPathComponent("group")
                                    .appendingPathComponent(group.id.uuidString),
                                subject: Text("Join \(group.name) on Click Split"),
                                message: Text("Join our group on Click Split to share expenses!")
                            ) {
                                Label("Invite", systemImage: "person.badge.plus")
                                    .font(SplitTypography.buttonSmall)
                                    .foregroundColor(SplitColors.green)
                            }
                        }

                        if isCreator {
                            HStack(spacing: SplitSpacing.sm) {
                                TextField("Member email", text: $memberEmail)
                                    .font(SplitTypography.body)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .padding(SplitSpacing.sm)
                                    .background(SplitColors.paper)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                            .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                                    )
                                    .onSubmit(addMember)

                                Button(action: addMember) {
                                    Group {
                                        if isAddingMember {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Text("Add")
                                        }
                                    }
                                    .font(SplitTypography.buttonSmall)
                                    .foregroundColor(SplitColors.paper)
                                    .frame(minWidth: 44)
                                    .padding(.horizontal, SplitSpacing.sm)
                                    .padding(.vertical, SplitSpacing.sm)
                                    .background(SplitColors.ink)
                                    .clipShape(RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius))
                                }
                                .buttonStyle(.plain)
                                .disabled(isAddingMember || removingMemberId != nil || memberEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }

                            Text("Add an existing Click account by email. Only the group creator can change membership.")
                                .font(SplitTypography.caption)
                                .foregroundColor(SplitColors.inkSoft)
                        }

                        VStack(spacing: SplitSpacing.xs) {
                            ForEach(managedMembers) { member in
                                HStack(spacing: SplitSpacing.sm) {
                                    Text(member.profile?.displayName ?? "Member")
                                        .font(SplitTypography.body)
                                        .foregroundColor(SplitColors.ink)

                                    if member.userId == group.createdBy {
                                        Text("CREATOR")
                                            .font(SplitTypography.badge)
                                            .foregroundColor(SplitColors.green)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(SplitColors.greenDim)
                                            .cornerRadius(4)
                                    }

                                    Spacer()

                                    if isCreator && member.userId != group.createdBy {
                                        Button {
                                            memberPendingRemoval = member
                                        } label: {
                                            if removingMemberId == member.userId {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "minus.circle")
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .foregroundColor(SplitColors.red)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(isAddingMember || removingMemberId != nil)
                                        .accessibilityLabel("Remove \(member.profile?.displayName ?? "member")")
                                    }
                                }
                                .padding(.vertical, SplitSpacing.xs)

                                if member.id != managedMembers.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(SplitSpacing.lg)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)

                    // Data & Export Section
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("DATA & EXPORT")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)
                            .tracking(1)

                        if let exportURL = csvExportURL {
                            ShareLink(
                                item: exportURL,
                                subject: Text("\(group.name) Expenses"),
                                message: Text("Here is the CSV export of expenses for \(group.name).")
                            ) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export Expenses as CSV")
                                }
                                .font(SplitTypography.button)
                                .foregroundColor(SplitColors.ink)
                                .frame(maxWidth: .infinity)
                                .padding(SplitSpacing.md)
                                .background(SplitColors.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                        .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(SplitSpacing.lg)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)

                    // Danger Zone Section
                    VStack(alignment: .leading, spacing: SplitSpacing.md) {
                        Text("DANGER ZONE")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.red)
                            .tracking(1)

                        SplitButton("Leave Group", icon: "rectangle.portrait.and.arrow.right", variant: .danger) {
                            showLeaveDialog = true
                        }

                        if isCreator {
                            SplitButton("Delete Group", icon: "trash", variant: .danger) {
                                showDeleteDialog = true
                            }
                        }
                    }
                    .padding(SplitSpacing.lg)
                    .splitCardStyle(surfaceColor: SplitColors.redDim, borderColor: SplitColors.red)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.red)
                    }
                }
                .padding(SplitSpacing.lg)
            }
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("Group Settings")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isLoading ? "Saving…" : "Done") {
                        saveAndDismiss()
                    }
                    .font(SplitTypography.buttonSmall)
                    .foregroundColor(SplitColors.ink)
                    .disabled(isLoading || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(
                "Leave Group",
                isPresented: $showLeaveDialog,
                titleVisibility: .visible
            ) {
                Button("Leave \(group.name)", role: .destructive) {
                    leaveGroup()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to leave this group? Make sure your balances are settled first.")
            }
            .confirmationDialog(
                "Delete Group",
                isPresented: $showDeleteDialog,
                titleVisibility: .visible
            ) {
                Button("Permanently Delete Group", role: .destructive) {
                    deleteGroup()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the group, all its expenses, items, shares, and settlement records for everyone. This cannot be undone.")
            }
            .confirmationDialog(
                "Remove Member",
                isPresented: Binding(
                    get: { memberPendingRemoval != nil },
                    set: { if !$0 { memberPendingRemoval = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let member = memberPendingRemoval {
                    Button("Remove \(member.profile?.displayName ?? "Member")", role: .destructive) {
                        removeMember(member)
                    }
                }
                Button("Cancel", role: .cancel) {
                    memberPendingRemoval = nil
                }
            } message: {
                Text("The member must have a settled balance before they can be removed. Their expense history will remain in the group.")
            }
        }
    }

    private func saveAndDismiss() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !isLoading else { return }

        let currentIcon = group.icon ?? "👥"
        guard trimmedName != group.name || selectedIcon != currentIcon else {
            dismiss()
            return
        }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                _ = try await environment.groupRepository.updateGroup(
                    groupId: group.id,
                    name: trimmedName,
                    icon: selectedIcon
                )
                isLoading = false
                SplitHaptics.notify(.success)
                onGroupModified()
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }

    private func addMember() {
        let email = memberEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !isAddingMember else { return }

        isAddingMember = true
        errorMessage = nil

        Task { @MainActor in
            do {
                try await environment.groupRepository.addGroupMember(groupId: group.id, email: email)
                managedMembers = try await environment.groupRepository.fetchGroupMembers(groupId: group.id)
                memberEmail = ""
                isAddingMember = false
                SplitHaptics.notify(.success)
                onGroupModified()
            } catch {
                isAddingMember = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }

    private func removeMember(_ member: SplitGroupMember) {
        guard removingMemberId == nil else { return }

        removingMemberId = member.userId
        memberPendingRemoval = nil
        errorMessage = nil

        Task { @MainActor in
            do {
                try await environment.groupRepository.removeGroupMember(
                    groupId: group.id,
                    userId: member.userId
                )
                managedMembers = try await environment.groupRepository.fetchGroupMembers(groupId: group.id)
                removingMemberId = nil
                SplitHaptics.notify(.success)
                onGroupModified()
            } catch {
                removingMemberId = nil
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }

    private func leaveGroup() {
        isLoading = true
        Task {
            do {
                try await environment.groupRepository.leaveGroup(groupId: group.id, userId: currentUserId)
                isLoading = false
                SplitHaptics.notify(.success)
                dismiss()
                onGroupExited()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }

    private func deleteGroup() {
        isLoading = true
        Task {
            do {
                try await environment.groupRepository.deleteGroup(groupId: group.id)
                isLoading = false
                SplitHaptics.notify(.success)
                dismiss()
                onGroupExited()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }
}
