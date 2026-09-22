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

    private let availableIcons = ["🍜", "🌲", "🏠", "✈️", "☕️", "🎉", "🛒", "🚗", "🏖️", "🍕"]

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
    }

    private var currentUserId: UUID {
        environment.sessionStore.currentUser?.id ?? UUID()
    }

    private var isCreator: Bool {
        group.createdBy == currentUserId
    }

    private var csvExportURL: URL? {
        let csv = CSVExporter.generateCSV(groupName: group.name, expenses: expenses, members: members)
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

                        HStack(spacing: SplitSpacing.sm) {
                            ForEach(availableIcons.prefix(5), id: \.self) { icon in
                                Button(action: {
                                    SplitHaptics.selection()
                                    selectedIcon = icon
                                }) {
                                    Text(icon)
                                        .font(.system(size: 22))
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? SplitColors.paperDim : SplitColors.paper)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                                .stroke(selectedIcon == icon ? SplitColors.green : SplitColors.ink, lineWidth: selectedIcon == icon ? 2.5 : 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        TextField("Group Name", text: $groupName)
                            .font(SplitTypography.body)
                            .padding(SplitSpacing.md)
                            .background(SplitColors.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                            )
                    }
                    .padding(SplitSpacing.lg)
                    .splitCardStyle(surfaceColor: SplitColors.paperDim)

                    // Members List Section
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        HStack {
                            Text("MEMBERS (\(members.count))")
                                .font(SplitTypography.badge)
                                .foregroundColor(SplitColors.inkSoft)
                                .tracking(1)

                            Spacer()

                            ShareLink(
                                item: URL(string: "https://clickplatforms.com/group/\(group.id)")!,
                                subject: Text("Join \(group.name) on Click Split"),
                                message: Text("Join our group on Click Split to share expenses!")
                            ) {
                                Label("Invite", systemImage: "person.badge.plus")
                                    .font(SplitTypography.buttonSmall)
                                    .foregroundColor(SplitColors.green)
                            }
                        }

                        VStack(spacing: SplitSpacing.xs) {
                            ForEach(members) { member in
                                HStack {
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
                                }
                                .padding(.vertical, SplitSpacing.xs)

                                if member.id != members.last?.id {
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
                    Button("Done") {
                        dismiss()
                    }
                    .font(SplitTypography.buttonSmall)
                    .foregroundColor(SplitColors.ink)
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
