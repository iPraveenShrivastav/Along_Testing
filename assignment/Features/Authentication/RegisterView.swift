//
//  RegisterView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct RegisterView: View {
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
                        Text("Create your account")
                            .font(.alongTitle)
                            .foregroundStyle(AlongTheme.Colors.primaryText)
                        Text("Your location is never shared until you turn it on.")
                            .font(.alongBody)
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                    }

                    if let error = viewModel.errorMessage {
                        AlongErrorBanner(message: error)
                    }

                    VStack(spacing: AlongTheme.Spacing.md) {
                        VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
                            AlongFormField(title: "Email", text: $viewModel.email,
                                           placeholder: "you@example.com",
                                           keyboardType: .emailAddress)
                            if !viewModel.email.isEmpty {
                                validationHint(
                                    isValid: (try? Validators.email(viewModel.email)) != nil,
                                    validText: "Email address looks good",
                                    invalidText: "Enter a valid email address"
                                )
                            }
                        }
                        VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
                            AlongFormField(title: "Password", text: $viewModel.password,
                                           placeholder: "At least 8 characters", isSecure: true,
                                           isNewPassword: true)
                            if !viewModel.password.isEmpty {
                                validationHint(
                                    isValid: viewModel.password.count >= Validators.minPasswordLength,
                                    validText: "At least 8 characters",
                                    invalidText: "Use at least 8 characters"
                                )
                            }
                        }
                        VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
                            AlongFormField(title: "Confirm password", text: $viewModel.confirmPassword,
                                           placeholder: "Repeat your password", isSecure: true,
                                           isNewPassword: true)
                            if !viewModel.confirmPassword.isEmpty {
                                validationHint(
                                    isValid: viewModel.confirmPassword == viewModel.password,
                                    validText: "Passwords match",
                                    invalidText: "Passwords do not match"
                                )
                            }
                        }
                    }

                    Button {
                        Task { await viewModel.register() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().tint(AlongTheme.Colors.onAccent)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Account")
                        }
                    }
                    .buttonStyle(.alongPrimary)
                    .disabled(viewModel.isLoading)

                    Text("By creating an account you agree to share your location only with groups you explicitly join, only while sharing is enabled.")
                        .font(.alongCaption)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
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

    @ViewBuilder
    private func validationHint(isValid: Bool, validText: String, invalidText: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .accessibilityHidden(true)
            Text(isValid ? validText : invalidText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.alongCaption)
        .foregroundStyle(isValid ? AlongTheme.Colors.accent : AlongTheme.Colors.danger)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }
}
