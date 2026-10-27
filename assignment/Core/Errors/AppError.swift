//
//  AppError.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct AppError: LocalizedError, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    init(_ error: Error) {
        self.message = AppError.describe(error)
    }

    var errorDescription: String? { message }

    static func describe(_ error: Error) -> String {
        if let appError = error as? AppError { return appError.message }
        if let validationError = error as? ValidationError {
            return validationError.errorDescription ?? "Invalid input."
        }
        let nsError = error as NSError
        if nsError.domain == "FIRAuthErrorDomain", let code = AuthErrorCode(rawValue: nsError.code) {
            return describeAuth(code)
        }
        if nsError.domain == FirestoreErrorDomain || nsError.domain.hasPrefix("FIRFirestore") {
            return describeFirestore(nsError)
        }
        if nsError.domain == NSURLErrorDomain {
            return "No internet connection. Check your network and try again."
        }
        return nsError.localizedDescription
    }

    private static func describeAuth(_ code: AuthErrorCode) -> String {
        switch code {
        case .wrongPassword, .invalidCredential:
            return "Incorrect email or password."
        case .userNotFound:
            return "No account exists for that email."
        case .emailAlreadyInUse:
            return "An account already exists for that email."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .invalidEmail:
            return "That email address isn't valid."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .tooManyRequests:
            return "Too many attempts. Please wait a moment and try again."
        case .userDisabled:
            return "This account has been disabled."
        default:
            return "Authentication failed. Please try again."
        }
    }

    private static func describeFirestore(_ error: NSError) -> String {
        switch FirestoreErrorCode.Code(rawValue: error.code) {
        case .permissionDenied:
            return "You don't have access to that data."
        case .unavailable:
            return "Firestore is unreachable. You may be offline."
        case .notFound:
            return "That item no longer exists."
        default:
            return "A data error occurred. Please try again."
        }
    }
}
