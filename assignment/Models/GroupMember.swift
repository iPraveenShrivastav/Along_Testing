//
//  GroupMember.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

enum GroupRole: String, Codable, Equatable {
    case owner
    case member

    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .member: return "Member"
        }
    }
}

struct GroupMember: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var role: GroupRole
    var displayName: String
    var joinedAt: Date?
    var sharingEnabled: Bool
}
