//
//  WelcomeView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var showSignIn = false
    @State private var showRegister = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 36)
                    Image("AlongLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: AlongTheme.Colors.accent.opacity(0.18), radius: 18, y: 8)
                        .accessibilityLabel("Along app logo")

                    VStack(spacing: AlongTheme.Spacing.sm) {
                        Text("Along")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(AlongTheme.Colors.primaryText)
                        Text("Private location sharing")
                            .font(.alongCaption.weight(.semibold))
                            .foregroundStyle(AlongTheme.Colors.accent)
                        Text("Stay close to your people, while you stay in control of when you share.")
                            .font(.alongBody)
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AlongTheme.Spacing.xl)
                    }
                    .padding(.top, AlongTheme.Spacing.lg)

                    Spacer(minLength: 40)

                    VStack(spacing: AlongTheme.Spacing.md) {
                        Button("Create Account") { showRegister = true }
                            .buttonStyle(.alongPrimary)
                        Button("Sign In") { showSignIn = true }
                            .buttonStyle(.alongSecondary)
                    }
                    .padding(.horizontal, AlongTheme.Spacing.lg)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, AlongTheme.Spacing.lg))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
        }
        .sheet(isPresented: $showSignIn) {
            SignInView(viewModel: makeViewModel())
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showRegister) {
            RegisterView(viewModel: makeViewModel())
                .presentationDetents([.large])
        }
    }

    private func makeViewModel() -> AuthViewModel {
        AuthViewModel(authService: appState.authService, userService: appState.userService)
    }
}
