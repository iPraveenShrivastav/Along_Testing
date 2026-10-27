//
//  AuthService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseAuth

@MainActor
final class AuthService {
    private var stateHandle: AuthStateDidChangeListenerHandle?

    var currentUser: User? { Auth.auth().currentUser }

    func startListening(_ onChange: @escaping @MainActor (User?) -> Void) {
        stopListening()
        stateHandle = Auth.auth().addStateDidChangeListener { _, user in
            MainActor.assumeIsolated {
                onChange(user)
            }
        }
    }

    func stopListening() {
        if let stateHandle {
            Auth.auth().removeStateDidChangeListener(stateHandle)
            self.stateHandle = nil
        }
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func register(displayName: String, email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        let change = result.user.createProfileChangeRequest()
        change.displayName = displayName
        try await change.commitChanges()
        return result.user
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
