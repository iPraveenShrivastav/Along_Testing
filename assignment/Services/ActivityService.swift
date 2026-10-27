//
//  ActivityService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class ActivityService {
    private var db: Firestore { Firestore.firestore() }

    static func deduplicationKey(memberUid: String, placeId: String,
                                 type: ActivityEventType, at date: Date = Date()) -> String {
        let bucket = Int(date.timeIntervalSince1970 / 60)
        let raw = "\(memberUid)_\(placeId)_\(type.rawValue)_\(bucket)"
        return raw.replacingOccurrences(of: "/", with: "-")
    }

    func record(groupID: String, type: ActivityEventType, memberUid: String,
                memberName: String, placeId: String? = nil, placeName: String? = nil,
                deduplicationKey: String, source: ActivityEventSource = .device) async throws {
        var data: [String: Any] = [
            "type": type.rawValue,
            "memberUid": memberUid,
            "memberName": memberName,
            "timestamp": FieldValue.serverTimestamp(),
            "source": source.rawValue,
            "deduplicationKey": deduplicationKey
        ]
        data["placeId"] = placeId
        data["placeName"] = placeName
        try await db.collection("groups").document(groupID)
            .collection("events").document(deduplicationKey)
            .setData(data)
    }
}
