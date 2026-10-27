//
//  AlongUser.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

struct AlongUser: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var displayName: String
    var email: String
    var createdAt: Date?
    var updatedAt: Date?
    var notificationsEnabled: Bool
    var fcmTokens: [String]?
}
