//
//  JoinGroupView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct JoinGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: GroupsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AlongTheme.Spacing.md) {
                    if viewModel.joinRequestSubmitted {
                        AlongStatusPill(text: "Request sent", tone: .active, systemImage: "checkmark.circle.fill")
                        Text("Your request is waiting for the group owner to approve it.")
                            .font(.alongBody)
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                    } else {
                        Text("Request to join")
                            .font(.alongTitle)
                            .foregroundStyle(AlongTheme.Colors.primaryText)
                        Text("Enter the group ID shared by the owner. You can join after they approve your request.")
                            .font(.alongBody)
                            .foregroundStyle(AlongTheme.Colors.secondaryText)

                        if let error = viewModel.errorMessage {
                            AlongErrorBanner(message: error)
                        }

                        AlongFormField(title: "Group ID", text: $viewModel.groupIDInput,
                                       placeholder: "Paste group ID")

                        Button {
                            Task {
                                await viewModel.requestToJoinGroup()
                            }
                        } label: {
                            if viewModel.isWorking {
                                ProgressView().tint(AlongTheme.Colors.onAccent).frame(maxWidth: .infinity)
                            } else {
                                Text("Send Join Request")
                            }
                        }
                        .buttonStyle(.alongPrimary)
                        .disabled(viewModel.isWorking)
                    }
                }
                .padding(AlongTheme.Spacing.lg)
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.joinRequestSubmitted ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }
}
