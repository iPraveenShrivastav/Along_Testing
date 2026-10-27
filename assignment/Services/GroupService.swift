//
//  GroupService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation
import FirebaseFirestore

@MainActor
final class GroupService {
    private var db: Firestore { Firestore.firestore() }

    private func groupRef(_ groupID: String) -> DocumentReference {
        db.collection("groups").document(groupID)
    }


    func myGroupsStream(uid: String) -> AsyncThrowingStream<[AlongGroup], Error> {
        stream(db.collection("groups")
            .whereField("memberIds", arrayContains: uid)
            .order(by: "createdAt", descending: true))
    }

    func membersStream(groupID: String) -> AsyncThrowingStream<[GroupMember], Error> {
        stream(groupRef(groupID).collection("members").order(by: "joinedAt"))
    }

    func locationsStream(groupID: String) -> AsyncThrowingStream<[SharedLocation], Error> {
        stream(groupRef(groupID).collection("locations"))
    }

    func savedPlacesStream(groupID: String) -> AsyncThrowingStream<[SavedPlace], Error> {
        stream(groupRef(groupID).collection("savedPlaces").order(by: "createdAt"))
    }

    func eventsStream(groupID: String, limit: Int = 50) -> AsyncThrowingStream<[ActivityEvent], Error> {
        stream(groupRef(groupID).collection("events")
            .order(by: "timestamp", descending: true)
            .limit(to: limit))
    }

    func joinRequestsStream(groupID: String) -> AsyncThrowingStream<[JoinRequest], Error> {
        stream(groupRef(groupID).collection("joinRequests")
            .order(by: "requestedAt"))
    }

    private func stream<T: Decodable>(_ query: Query) -> AsyncThrowingStream<[T], Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                let items = (snapshot?.documents ?? []).compactMap { document in
                    try? document.data(as: T.self)
                }
                continuation.yield(items)
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }


    func createGroup(name: String, uid: String, displayName: String) async throws -> String {
        let groupID = db.collection("groups").document().documentID
        let ref = groupRef(groupID)
        let batch = db.batch()
        batch.setData([
            "name": name,
            "createdBy": uid,
            "memberIds": [uid],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: ref)
        batch.setData([
            "role": GroupRole.owner.rawValue,
            "displayName": displayName,
            "joinedAt": FieldValue.serverTimestamp(),
            "sharingEnabled": false
        ], forDocument: ref.collection("members").document(uid))
        try await batch.commit()
        return groupID
    }

    func submitJoinRequest(groupID: String, uid: String, displayName: String) async throws {
        let normalizedID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, !normalizedID.contains("/") else {
            throw AppError("Enter the group ID shared by the group owner.")
        }

        let requestRef = groupRef(normalizedID).collection("joinRequests").document(uid)
        let existing = try await requestRef.getDocument()
        if existing.exists {
            let status = existing.data()?["status"] as? String
            if status == "pending" {
                throw AppError("Your request is already waiting for owner approval.")
            }
            if status == "approved" {
                throw AppError("You already belong to this group.")
            }
            try await requestRef.updateData([
                "displayName": displayName,
                "requestedAt": FieldValue.serverTimestamp(),
                "status": "pending",
                "reviewedAt": FieldValue.delete(),
                "reviewedBy": FieldValue.delete()
            ])
        } else {
            try await requestRef.setData([
                "displayName": displayName,
                "requestedAt": FieldValue.serverTimestamp(),
                "status": "pending"
            ])
        }
    }

    func reviewJoinRequest(groupID: String, requesterUID: String,
                           ownerUID: String, approve: Bool) async throws {
        let group = groupRef(groupID)
        let requestRef = group.collection("joinRequests").document(requesterUID)
        let requestSnapshot = try await requestRef.getDocument()
        guard requestSnapshot.data()?["status"] as? String == "pending" else {
            throw AppError("This join request is no longer pending.")
        }

        let status = approve ? "approved" : "rejected"
        let batch = db.batch()

        if approve {
            let groupSnapshot = try await group.getDocument()
            guard groupSnapshot.data()?["createdBy"] as? String == ownerUID else {
                throw AppError("Only the group owner can approve requests.")
            }
            let memberRef = group.collection("members").document(requesterUID)
            let memberSnapshot = try await memberRef.getDocument()
            guard !memberSnapshot.exists else {
                throw AppError("This person is already a group member.")
            }
            let name = requestSnapshot.data()?["displayName"] as? String ?? "Member"
            batch.updateData([
                "memberIds": FieldValue.arrayUnion([requesterUID]),
                "updatedAt": FieldValue.serverTimestamp(),
                "lastApprovedUid": requesterUID
            ], forDocument: group)
            batch.setData([
                "role": GroupRole.member.rawValue,
                "displayName": name,
                "joinedAt": FieldValue.serverTimestamp(),
                "sharingEnabled": false
            ], forDocument: memberRef)
        }

        batch.updateData([
            "status": status,
            "reviewedAt": FieldValue.serverTimestamp(),
            "reviewedBy": ownerUID
        ], forDocument: requestRef)
        try await batch.commit()
    }

    func removeMember(groupID: String, ownerUID: String, memberUID: String) async throws {
        guard ownerUID != memberUID else {
            throw AppError("Use Leave Group to remove yourself.")
        }
        let group = groupRef(groupID)
        let groupSnapshot = try await group.getDocument()
        guard groupSnapshot.data()?["createdBy"] as? String == ownerUID else {
            throw AppError("Only the group owner can remove members.")
        }

        let batch = db.batch()
        batch.updateData([
            "memberIds": FieldValue.arrayRemove([memberUID]),
            "updatedAt": FieldValue.serverTimestamp(),
            "lastRemovedUid": memberUID
        ], forDocument: group)
        batch.deleteDocument(group.collection("members").document(memberUID))
        batch.deleteDocument(group.collection("locations").document(memberUID))
        batch.deleteDocument(group.collection("joinRequests").document(memberUID))
        try await batch.commit()
    }

    func leaveGroup(groupID: String, uid: String) async throws {
        let ref = groupRef(groupID)
        let groupDoc = try await ref.getDocument()
        guard groupDoc.exists, let group = try? groupDoc.data(as: AlongGroup.self) else {
            throw AppError("That group no longer exists.")
        }
        let members = try await ref.collection("members").getDocuments()
        if members.documents.count <= 1 {
            try await deleteGroupDocuments(groupID: groupID, ownerUID: uid)
            return
        }

        let batch = db.batch()
        batch.deleteDocument(ref.collection("members").document(uid))
        batch.deleteDocument(ref.collection("locations").document(uid))

        var updates: [String: Any] = [
            "memberIds": FieldValue.arrayRemove([uid]),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if group.createdBy == uid,
           let successor = members.documents.first(where: { $0.documentID != uid }) {
            updates["createdBy"] = successor.documentID
            batch.updateData(["role": GroupRole.owner.rawValue],
                             forDocument: successor.reference)
        }
        batch.updateData(updates, forDocument: ref)
        try await batch.commit()
    }

    func deleteGroup(groupID: String, uid: String) async throws {
        try await deleteGroupDocuments(groupID: groupID, ownerUID: uid)
    }

    private func deleteGroupDocuments(groupID: String, ownerUID: String) async throws {
        let ref = groupRef(groupID)
        let groupDoc = try await ref.getDocument()
        guard let group = try? groupDoc.data(as: AlongGroup.self), group.createdBy == ownerUID else {
            throw AppError("Only the group owner can delete this group.")
        }
        let subcollections = ["members", "locations", "savedPlaces", "events", "joinRequests"]
        var documents: [DocumentReference] = []
        let ownerMember = ref.collection("members").document(ownerUID)
        for collection in subcollections {
            let snapshot = try await ref.collection(collection).getDocuments()
            documents.append(contentsOf: snapshot.documents
                .map(\.reference)
                .filter { $0.path != ownerMember.path })
        }

        let chunkSize = 400
        for start in stride(from: 0, to: documents.count, by: chunkSize) {
            let end = min(start + chunkSize, documents.count)
            let batch = db.batch()
            for document in documents[start..<end] {
                batch.deleteDocument(document)
            }
            try await batch.commit()
        }
        let finalBatch = db.batch()
        finalBatch.deleteDocument(ownerMember)
        finalBatch.deleteDocument(ref)
        try await finalBatch.commit()
    }


    func setSharing(groupID: String, uid: String, enabled: Bool) async throws {
        let batch = db.batch()
        batch.updateData([
            "sharingEnabled": enabled
        ], forDocument: groupRef(groupID).collection("members").document(uid))
        if !enabled {
            batch.deleteDocument(groupRef(groupID).collection("locations").document(uid))
        }
        try await batch.commit()
    }

    func writeLocation(groupID: String, uid: String, location: CLLocation) async throws {
        try Validators.shareableLocation(location)
        try await groupRef(groupID).collection("locations").document(uid).setData([
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "horizontalAccuracy": location.horizontalAccuracy,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }


    func createSavedPlace(groupID: String, placeID: String, name: String,
                          coordinate: CLLocationCoordinate2D,
                          radius: CLLocationDistance, uid: String,
                          enabled: Bool = true) async throws -> String {
        try Validators.coordinate(coordinate)
        try Validators.placeRadius(radius)
        let ref = groupRef(groupID).collection("savedPlaces").document(placeID)
        try await ref.setData([
            "name": name,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "radius": radius,
            "createdBy": uid,
            "enabled": enabled,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return ref.documentID
    }

    func updateSavedPlace(groupID: String, placeID: String, name: String,
                          radius: CLLocationDistance, enabled: Bool) async throws {
        try Validators.placeRadius(radius)
        try await groupRef(groupID).collection("savedPlaces").document(placeID).updateData([
            "name": name,
            "radius": radius,
            "enabled": enabled
        ])
    }

    func deleteSavedPlace(groupID: String, placeID: String) async throws {
        try await groupRef(groupID).collection("savedPlaces").document(placeID).delete()
    }
}
