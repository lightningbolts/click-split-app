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

    private let availableIcons = ["🍜", "🌲", "🏠", "✈️", "☕️", "🎉", "🛒", "🚗"]

    public init(onGroupCreated: @escaping (SplitGroup) -> Void) {
        self.onGroupCreated = onGroupCreated
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplitSpacing.xl) {
                // Icon Selector
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("CHOOSE ICON")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)

                    HStack(spacing: SplitSpacing.sm) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: {
                                SplitHaptics.selection()
                                selectedIcon = icon
                            }) {
                                Text(icon)
                                    .font(.system(size: 24))
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
                }

                // Name Input
                VStack(alignment: .leading, spacing: SplitSpacing.sm) {
                    Text("GROUP NAME")
                        .font(SplitTypography.badge)
                        .foregroundColor(SplitColors.inkSoft)

                    TextField("e.g. Vancouver Trip, Roommates", text: $groupName)
                        .font(SplitTypography.body)
                        .padding(SplitSpacing.md)
                        .background(SplitColors.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                                .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                        )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.red)
                }

                Spacer()

                // Create Button
                SplitButton("Create group", icon: "checkmark", variant: .primary, isLoading: isLoading) {
                    createGroup()
                }
                .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(SplitSpacing.xl)
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
