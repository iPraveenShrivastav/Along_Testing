//
//  ProfileSheet.swift
//  assignment
//
//  Created by praveen on 28/10/26.
//

import SwiftUI

struct ProfileSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProfileViewModel?
    @State private var confirmSignOut = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AlongTheme.Spacing.lg) {
                    if let error = viewModel?.errorMessage {
                        AlongErrorBanner(message: error)
                    }

                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
                        AlongSectionHeader(title: "Account")
                        AlongCard {
                            HStack(spacing: AlongTheme.Spacing.md) {
                                AlongAvatar(name: appState.user?.displayName ?? "?", size: 48)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(appState.user?.displayName ?? "—")
                                        .font(.alongHeadline)
                                        .foregroundStyle(AlongTheme.Colors.primaryText)
                                    Text(appState.user?.email ?? "—")
                                        .font(.alongCaption)
                                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                                        .textSelection(.enabled)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
                        AlongSectionHeader(title: "Notifications")
                        AlongCard {
                            Toggle("Notifications", isOn: Binding(
                                get: { appState.user?.notificationsEnabled ?? false },
                                set: { enabled in
                                    Task { await viewModel?.setNotificationsEnabled(enabled) }
                                }
                            ))
                            .tint(AlongTheme.Colors.accent)
                            .accessibilityHint("Controls notifications for saved place events")
                        }
                    }

                    Button("Sign Out", role: .destructive) {
                        confirmSignOut = true
                    }
                    .font(.alongHeadline)
                    .foregroundStyle(AlongTheme.Colors.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AlongTheme.Colors.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous)
                            .strokeBorder(AlongTheme.Colors.danger.opacity(0.42), lineWidth: 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous))
                    .accessibilityHint("Signs out of your Along account")
                    .buttonStyle(.plain)
                }
                .padding(AlongTheme.Spacing.lg)
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if viewModel == nil { viewModel = ProfileViewModel(appState: appState) }
            }
            .alert("Sign out?", isPresented: $confirmSignOut) {
                Button("Sign Out", role: .destructive) {
                    Task { await viewModel?.signOut() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out of Along?")
            }
        }
    }
}
