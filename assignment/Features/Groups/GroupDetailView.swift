//
//  GroupDetailView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct GroupDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GroupsViewModel?
    @State private var activeConfirmation: GroupConfirmation?

    let groupID: String

    private var group: AlongGroup? {
        appState.groups.first { $0.id == groupID }
    }

    private var members: [GroupMember] {
        appState.session?.groupID == groupID ? (appState.session?.members ?? []) : []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AlongTheme.Spacing.lg) {
                if let error = viewModel?.errorMessage {
                    AlongErrorBanner(message: error)
                }
                if let sessionError = appState.session?.error, appState.session?.groupID == groupID {
                    AlongErrorBanner(message: sessionError)
                }

                membersSection
                groupIDSection
                if group?.createdBy == appState.uid {
                    joinRequestsSection
                }
                dangerSection
            }
            .padding(AlongTheme.Spacing.lg)
        }
        .background(AlongTheme.Colors.background.ignoresSafeArea())
        .navigationTitle(group?.name ?? "Group")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil { viewModel = GroupsViewModel(appState: appState) }
            if appState.selectedGroupID != groupID {
                appState.selectedGroupID = groupID
            }
        }
        .alert(
            activeConfirmation?.title ?? "",
            isPresented: Binding(
                get: { activeConfirmation != nil },
                set: { if !$0 { activeConfirmation = nil } }
            ),
            presenting: activeConfirmation
        ) { confirmation in
            Button(confirmation.actionTitle, role: .destructive) {
                perform(confirmation)
            }
            Button("Cancel", role: .cancel) {
                activeConfirmation = nil
            }
        } message: { confirmation in
            Text(confirmation.message)
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
            AlongSectionHeader(title: "Members")
            if members.isEmpty {
                Text("Members load for the selected group.")
                    .font(.alongCaption)
                    .foregroundStyle(AlongTheme.Colors.secondaryText)
            }
            ForEach(members) { member in
                AlongCard {
                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
                        HStack(spacing: AlongTheme.Spacing.md) {
                            AlongAvatar(name: member.displayName, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName + (member.id == appState.uid ? " (you)" : ""))
                                    .font(.alongHeadline)
                                    .foregroundStyle(AlongTheme.Colors.primaryText)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text(member.role.displayName)
                                    .font(.alongCaption)
                                    .foregroundStyle(AlongTheme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            AlongStatusPill(
                                text: member.sharingEnabled ? "Sharing" : "Paused",
                                tone: member.sharingEnabled ? .active : .paused
                            )
                            .frame(width: 78)
                        }
                        HStack {
                            Spacer(minLength: 0)
                            if group?.createdBy == appState.uid, member.id != appState.uid {
                                Button("Remove", role: .destructive) {
                                    activeConfirmation = .remove(member)
                                }
                                .font(.alongCaption)
                                .frame(width: 76, height: 34)
                            } else {
                                Color.clear.frame(width: 76, height: 34)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupIDSection: some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
            AlongSectionHeader(title: "Group ID")
            Text("Share this ID so people can request to join. They need your approval before they become members.")
                .font(.alongCaption)
                .foregroundStyle(AlongTheme.Colors.secondaryText)
            AlongCard {
                HStack {
                    Text(groupID)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .textSelection(.enabled)
                    Spacer()
                    ShareLink(item: "Request to join my Along group. Group ID: \(groupID)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share group ID")
                }
            }
        }
    }

    private var joinRequestsSection: some View {
        let requests = (appState.session?.groupID == groupID
            ? (appState.session?.joinRequests ?? []) : [])
            .filter { $0.status == "pending" }

        return VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
            AlongSectionHeader(title: "Join requests")
            if requests.isEmpty {
                Text("No pending requests.")
                    .font(.alongCaption)
                    .foregroundStyle(AlongTheme.Colors.secondaryText)
            }
            ForEach(requests) { request in
                AlongCard {
                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
                        Text(request.displayName)
                            .font(.alongHeadline)
                            .foregroundStyle(AlongTheme.Colors.primaryText)
                        HStack {
                            Button {
                                Task { await viewModel?.reviewJoinRequest(request, approve: false) }
                            } label: {
                                Text("Decline\nRequest")
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, minHeight: 54)
                            }
                            .buttonStyle(.alongSecondary)
                            Button {
                                Task { await viewModel?.reviewJoinRequest(request, approve: true) }
                            } label: {
                                Text("Approve\nRequest")
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, minHeight: 54)
                            }
                            .buttonStyle(.alongPrimary)
                        }
                        .disabled(viewModel?.isWorking == true)
                    }
                }
            }
        }
    }

    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
            AlongSectionHeader(title: "Danger zone")
            GroupDangerButton(title: "Leave Group") { activeConfirmation = .leave }
            if group?.createdBy == appState.uid {
                GroupDangerButton(title: "Delete Group") { activeConfirmation = .delete }
            }
        }
    }

    private func perform(_ confirmation: GroupConfirmation) {
        activeConfirmation = nil
        switch confirmation {
        case .leave:
            Task {
                do {
                    try await viewModel?.leaveGroup()
                    dismiss()
                } catch {
                    viewModel?.errorMessage = AppError(error).message
                }
            }
        case .delete:
            Task {
                do {
                    try await viewModel?.deleteGroup()
                    dismiss()
                } catch {
                    viewModel?.errorMessage = AppError(error).message
                }
            }
        case .remove(let member):
            Task { await viewModel?.removeMember(member) }
        }
    }
}

private enum GroupConfirmation {
    case leave
    case delete
    case remove(GroupMember)

    var title: String {
        switch self {
        case .leave: "Leave this group?"
        case .delete: "Delete this group?"
        case .remove: "Remove this member?"
        }
    }

    var actionTitle: String {
        switch self {
        case .leave: "Leave Group"
        case .delete: "Delete Group"
        case .remove: "Remove Member"
        }
    }

    var message: String {
        switch self {
        case .leave: "You'll stop sharing and seeing locations in this group."
        case .delete: "This removes the group and its member locations for everyone. This can't be undone."
        case .remove: "They will lose access to this group's locations and saved places."
        }
    }
}

private struct GroupDangerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.alongHeadline)
                .foregroundStyle(AlongTheme.Colors.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    AlongTheme.Colors.danger.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous)
                        .strokeBorder(AlongTheme.Colors.danger.opacity(0.42), lineWidth: 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
