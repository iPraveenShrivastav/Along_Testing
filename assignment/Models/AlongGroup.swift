//
//  AlongGroup.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

struct AlongGroup: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var createdBy: String
    var memberIds: [String]
    var createdAt: Date?
    var updatedAt: Date?

    func isOwner(_ uid: String) -> Bool { createdBy == uid }
}
