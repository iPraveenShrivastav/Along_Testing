//
//  SignInView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AlongTheme.Spacing.lg) {
                    Image("AlongLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Along app logo")

                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
                        Text("Welcome back")
                            .font(.alongTitle)
                            .foregroundStyle(AlongTheme.Colors.primaryText)
                        Text("Sign in to continue to your groups.")
                            .font(.alongBody)
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                    }

                    if let error = viewModel.errorMessage {
                        AlongErrorBanner(message: error)
                    }
                    if viewModel.resetSent {
                        AlongErrorBanner(message: "Password reset email sent. Check your inbox.")
                    }

                    VStack(spacing: AlongTheme.Spacing.md) {
                        AlongFormField(title: "Email", text: $viewModel.email,
                                       placeholder: "you@example.com",
                                       keyboardType: .emailAddress)
                        AlongFormField(title: "Password", text: $viewModel.password,
                                       placeholder: "Your password", isSecure: true)
                    }

                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().tint(AlongTheme.Colors.onAccent)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.alongPrimary)
                    .disabled(viewModel.isLoading)

                    Button("Forgot password?") {
                        Task { await viewModel.sendPasswordReset() }
                    }
                    .font(.alongCaption)
                    .foregroundStyle(AlongTheme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .disabled(viewModel.isLoading)
                }
                .padding(AlongTheme.Spacing.lg)
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
