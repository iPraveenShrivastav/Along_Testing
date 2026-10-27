//
//  JoinRequest.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

struct JoinRequest: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var displayName: String
    var requestedAt: Date?
    var status: String
    var reviewedAt: Date?
    var reviewedBy: String?
}
