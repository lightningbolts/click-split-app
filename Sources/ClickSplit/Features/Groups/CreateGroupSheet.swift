import SwiftUI

/// Modal sheet for creating a new group.
public struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment
    @State private var groupName: String = ""
    @State private var selectedIcon: String = "🍜"
    @State private var isLoading = false
    @State private var errorMessage: String?

    public var onGroupCreated: (SplitGroup) -> Void

    public init(onGroupCreated: @escaping (SplitGroup) -> Void) {
        self.onGroupCreated = onGroupCreated
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                    // Group Name Input
                    VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                        Text("GROUP NAME")
                            .font(SplitTypography.badge)
                            .foregroundColor(SplitColors.inkSoft)
                            .tracking(1)

                        TextField("e.g. Vancouver Trip, Roommates", text: $groupName)
                            .font(SplitTypography.body)
                            .padding(SplitSpacing.md)
                            .background(SplitColors.paper)
                            .overlay(
                                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                    .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                            )
                    }

                    // Complete Icon Selector with Categories & Custom Input
                    GroupIconPicker(selectedIcon: $selectedIcon)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(SplitTypography.caption)
                            .foregroundColor(SplitColors.red)
                    }

                    // Create Button
                    SplitButton("Create group", icon: "checkmark", variant: .primary, isLoading: isLoading) {
                        createGroup()
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.top, SplitSpacing.md)
                }
                .padding(SplitSpacing.xl)
            }
            .background(SplitColors.paper.ignoresSafeArea())
            .navigationTitle("New Group")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
        }
    }

    private func createGroup() {
        guard let currentUserId = environment.sessionStore.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let newGroup = try await environment.groupRepository.createGroup(
                    name: groupName.trimmingCharacters(in: .whitespaces),
                    icon: selectedIcon,
                    createdBy: currentUserId
                )
                isLoading = false
                onGroupCreated(newGroup)
                dismiss()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
