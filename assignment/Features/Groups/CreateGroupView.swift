//
//  CreateGroupView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GroupsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AlongTheme.Spacing.lg) {
                    if viewModel.createdGroupID != nil {
                        successSection(groupID: viewModel.createdGroupID ?? "")
                    } else {
                        formSection
                    }
                }
                .padding(AlongTheme.Spacing.lg)
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(viewModel.createdGroupID == nil ? "Create Group" : "Group Created")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.createdGroupID == nil ? "Cancel" : "Done") { dismiss() }
                }
            }
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.md) {
            Text("Name your group")
                .font(.alongTitle)
                .foregroundStyle(AlongTheme.Colors.primaryText)
            Text("People can request to join with the group ID. You approve each request, and location sharing stays off until members turn it on.")
                .font(.alongBody)
                .foregroundStyle(AlongTheme.Colors.secondaryText)

            if let error = viewModel.errorMessage {
                AlongErrorBanner(message: error)
            }

            AlongFormField(title: "Group name", text: $viewModel.groupName,
                           placeholder: "e.g. Family, Weekend hikers")

            Button {
                Task { await viewModel.createGroup() }
            } label: {
                if viewModel.isWorking {
                    ProgressView().tint(AlongTheme.Colors.onAccent).frame(maxWidth: .infinity)
                } else {
                    Text("Create Group")
                }
            }
            .buttonStyle(.alongPrimary)
            .disabled(viewModel.isWorking)
        }
    }

    private func successSection(groupID: String) -> some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.md) {
            AlongStatusPill(text: "Group created", tone: .active, systemImage: "checkmark.circle.fill")

            Text("Share this group ID. People who enter it can request to join, and you can approve them from group details.")
                .font(.alongBody)
                .foregroundStyle(AlongTheme.Colors.secondaryText)
            AlongCard {
                HStack {
                    Text(groupID)
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .foregroundStyle(AlongTheme.Colors.primaryText)
                        .textSelection(.enabled)
                    Spacer()
                    ShareLink(item: "Request to join my Along group. Group ID: \(groupID)") {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AlongTheme.Colors.accent)
                    }
                    .accessibilityLabel("Share group ID")
                }
            }

            Button("Done") { dismiss() }
                .buttonStyle(.alongSecondary)
        }
    }
}
