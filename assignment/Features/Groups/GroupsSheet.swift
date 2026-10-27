//
//  GroupsSheet.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct GroupsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GroupsViewModel?
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if appState.groups.isEmpty {
                    AlongEmptyState(
                        systemImage: "person.3",
                        title: "No groups yet",
                        message: "Create a group or request to join one using its group ID."
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: AlongTheme.Spacing.sm) {
                            ForEach(appState.groups) { group in
                                GroupRowView(
                                    group: group,
                                    onSelect: {
                                        appState.selectedGroupID = group.id
                                        dismiss()
                                    },
                                    onDetails: {
                                        if let id = group.id { path.append(id) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, AlongTheme.Spacing.sm)
                    }
                }
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Create Group") { showCreate = true }
                        Button("Request to Join") { showJoin = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create or join a group")
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateGroupView(viewModel: viewModel ?? GroupsViewModel(appState: appState))
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showJoin) {
                JoinGroupView(viewModel: viewModel ?? GroupsViewModel(appState: appState))
                    .presentationDetents([.medium])
            }
            .onAppear {
                if viewModel == nil { viewModel = GroupsViewModel(appState: appState) }
            }
            .navigationDestination(for: String.self) { groupID in
                GroupDetailView(groupID: groupID)
            }
        }
    }
}

struct GroupRowView: View {
    @Environment(AppState.self) private var appState
    let group: AlongGroup
    let onSelect: () -> Void
    let onDetails: () -> Void

    var body: some View {
        AlongCard {
            HStack(spacing: AlongTheme.Spacing.md) {
                Button(action: onSelect) {
                    HStack(spacing: AlongTheme.Spacing.md) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(AlongTheme.Colors.accent)
                            .frame(width: 40, height: 40)
                            .background(AlongTheme.Colors.accentSoft, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .font(.alongHeadline)
                                .foregroundStyle(AlongTheme.Colors.primaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(group.memberIds.count) member\(group.memberIds.count == 1 ? "" : "s") · \(group.isOwner(appState.uid ?? "") ? "Owner" : "Member")")
                                .font(.alongCaption)
                                .foregroundStyle(AlongTheme.Colors.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Selects this group for the map")
                if let id = group.id, appState.sharingGroupIDs.contains(id) {
                    VStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.caption.weight(.semibold))
                        Text("Sharing")
                            .font(.system(.caption2, design: .rounded).weight(.medium))
                    }
                    .foregroundStyle(AlongTheme.Colors.accent)
                    .frame(width: 52, height: 44)
                    .background(AlongTheme.Colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Color.clear.frame(width: 52, height: 44)
                }
                if group.id == appState.selectedGroupID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AlongTheme.Colors.accent)
                        .frame(width: 20)
                        .accessibilityLabel("Selected group")
                } else {
                    Color.clear.frame(width: 20)
                }
                Button(action: onDetails) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("\(group.name) details")
            }
        }
    }
}
