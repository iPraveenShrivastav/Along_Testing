//
//  FirebaseConfigurator.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseCore

enum FirebaseConfigurator {
    static var isConfigured: Bool {
        Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    @discardableResult
    static func configureIfPossible() -> Bool {
        guard isConfigured else { return false }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return true
    }
}
