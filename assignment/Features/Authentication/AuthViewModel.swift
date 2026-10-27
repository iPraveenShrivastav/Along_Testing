//
//  AuthViewModel.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseAuth

@MainActor @Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var resetSent = false

    private let authService: AuthService
    private let userService: UserService

    init(authService: AuthService, userService: UserService) {
        self.authService = authService
        self.userService = userService
    }

    func signIn() async {
        errorMessage = nil
        do {
            let validEmail = try Validators.email(email)
            _ = try Validators.password(password)
            try await run { _ = try await authService.signIn(email: validEmail, password: password) }
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func register() async {
        errorMessage = nil
        do {
            let validEmail = try Validators.email(email)
            let name = "Along User"
            _ = try Validators.password(password)
            try Validators.confirmation(confirmPassword, matches: password)
            try await run {
                let user = try await authService.register(
                    displayName: name, email: validEmail, password: password
                )
                try await userService.ensureProfile(uid: user.uid, email: validEmail, displayName: name)
            }
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func sendPasswordReset() async {
        errorMessage = nil
        resetSent = false
        do {
            let validEmail = try Validators.email(email)
            try await run {
                try await authService.sendPasswordReset(email: validEmail)
            }
            resetSent = true
        } catch {
            errorMessage = AppError(error).message
        }
    }

    private func run(_ operation: () async throws -> Void) async throws {
        isLoading = true
        defer { isLoading = false }
        try await operation()
    }
}
