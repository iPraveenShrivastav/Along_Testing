//
//  ActivityEvent.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

enum ActivityEventType: String, Codable, Equatable {
    case arrived
    case departed
    case groupCreated
    case memberJoined
    case memberLeft
    case sharingStarted
    case sharingPaused

    var title: String {
        switch self {
        case .arrived: return "arrived at"
        case .departed: return "left"
        case .groupCreated: return "created the group"
        case .memberJoined: return "joined the group"
        case .memberLeft: return "left the group"
        case .sharingStarted: return "started sharing location"
        case .sharingPaused: return "paused location sharing"
        }
    }

    var systemImage: String {
        switch self {
        case .arrived: return "mappin.circle.fill"
        case .departed: return "figure.walk.departure"
        case .groupCreated: return "person.3.fill"
        case .memberJoined: return "person.badge.plus"
        case .memberLeft: return "person.badge.minus"
        case .sharingStarted: return "location.fill"
        case .sharingPaused: return "location.slash.fill"
        }
    }
}

enum ActivityEventSource: String, Codable {
    case device
    case server
}

struct ActivityEvent: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var type: ActivityEventType
    var memberUid: String
    var memberName: String
    var placeId: String?
    var placeName: String?
    var timestamp: Date?
    var source: ActivityEventSource
    var deduplicationKey: String

    var summary: String {
        if let placeName, !placeName.isEmpty {
            return "\(memberName) \(type.title) \(placeName)"
        }
        return "\(memberName) \(type.title)"
    }
}
