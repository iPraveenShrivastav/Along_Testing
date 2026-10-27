//
//  UserService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class UserService {
    private var db: Firestore { Firestore.firestore() }

    func profileStream(uid: String) -> AsyncThrowingStream<AlongUser?, Error> {
        let doc = db.collection("users").document(uid)
        return AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let registration = doc.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot, snapshot.exists else {
                    continuation.yield(nil)
                    return
                }
                continuation.yield(try? snapshot.data(as: AlongUser.self))
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    @discardableResult
    func ensureProfile(uid: String, email: String, displayName: String) async throws -> AlongUser {
        let ref = db.collection("users").document(uid)
        let requestedName = Validators.trimmed(displayName)
        let nameToStore = requestedName.isEmpty ? "Along User" : requestedName

        return try await withCheckedThrowingContinuation { continuation in
            db.runTransaction({ transaction, errorPointer -> Any? in
                do {
                    let snapshot = try transaction.getDocument(ref)
                    if snapshot.exists {
                        guard var user = try? snapshot.data(as: AlongUser.self) else {
                            throw AppError("Your account profile could not be read.")
                        }

                        let savedName = Validators.trimmed(user.displayName)
                        if savedName.isEmpty {
                            transaction.updateData([
                                "displayName": nameToStore,
                                "updatedAt": FieldValue.serverTimestamp()
                            ], forDocument: ref)
                            user.displayName = nameToStore
                            user.updatedAt = Date()
                        }
                        return user
                    }

                    let profile = AlongUser(
                        id: uid,
                        displayName: nameToStore,
                        email: email,
                        createdAt: Date(),
                        updatedAt: Date(),
                        notificationsEnabled: false,
                        fcmTokens: nil
                    )
                    transaction.setData([
                        "displayName": profile.displayName,
                        "email": email,
                        "createdAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp(),
                        "notificationsEnabled": false
                    ], forDocument: ref)
                    return profile
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let profile = result as? AlongUser {
                    continuation.resume(returning: profile)
                } else {
                    continuation.resume(throwing: AppError("Your account profile could not be saved."))
                }
            }
        }
    }

    func updateDisplayName(uid: String, displayName: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "displayName": displayName,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func setNotificationsEnabled(uid: String, enabled: Bool) async throws {
        try await db.collection("users").document(uid).updateData([
            "notificationsEnabled": enabled,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func addFCMToken(uid: String, token: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "fcmTokens": FieldValue.arrayUnion([token]),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
}
