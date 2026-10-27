//
//  GroupsViewModel.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation

@MainActor @Observable
final class GroupsViewModel {
    var groupName = ""
    var groupIDInput = ""
    var isWorking = false
    var errorMessage: String?
    var createdGroupID: String?
    var joinRequestSubmitted = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func createGroup() async {
        errorMessage = nil
        createdGroupID = nil
        do {
            let name = try Validators.groupName(groupName)
            guard let uid = appState.uid else { return }
            isWorking = true
            defer { isWorking = false }
            let displayName = appState.user?.displayName ?? "Member"
            let groupID = try await appState.groupService.createGroup(
                name: name, uid: uid, displayName: displayName
            )
            createdGroupID = groupID
            appState.selectedGroupID = groupID
            await recordSystemEvent(type: .groupCreated, groupID: groupID)
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func requestToJoinGroup() async {
        errorMessage = nil
        joinRequestSubmitted = false
        do {
            guard let uid = appState.uid else { throw AppError("Sign in to request group access.") }
            isWorking = true
            defer { isWorking = false }
            try await appState.groupService.submitJoinRequest(
                groupID: groupIDInput,
                uid: uid,
                displayName: appState.user?.displayName ?? "Member"
            )
            joinRequestSubmitted = true
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func reviewJoinRequest(_ request: JoinRequest, approve: Bool) async {
        errorMessage = nil
        guard let groupID = appState.selectedGroupID,
              let requesterUID = request.id,
              let ownerUID = appState.uid else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.groupService.reviewJoinRequest(
                groupID: groupID,
                requesterUID: requesterUID,
                ownerUID: ownerUID,
                approve: approve
            )
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func removeMember(_ member: GroupMember) async {
        errorMessage = nil
        guard let groupID = appState.selectedGroupID,
              let ownerUID = appState.uid,
              let memberUID = member.id else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await appState.groupService.removeMember(
                groupID: groupID, ownerUID: ownerUID, memberUID: memberUID
            )
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func leaveGroup() async throws {
        guard let uid = appState.uid, let groupID = appState.selectedGroupID else { return }
        await recordSystemEvent(type: .memberLeft, groupID: groupID)
        try await appState.groupService.leaveGroup(groupID: groupID, uid: uid)
        if appState.selectedGroupID == groupID {
            appState.selectedGroupID = appState.groups.first { $0.id != groupID }?.id
        }
    }

    func deleteGroup() async throws {
        guard let uid = appState.uid, let groupID = appState.selectedGroupID else { return }
        try await appState.groupService.deleteGroup(groupID: groupID, uid: uid)
        appState.selectedGroupID = nil
    }

    private func recordSystemEvent(type: ActivityEventType, groupID: String) async {
        guard let uid = appState.uid else { return }
        let name = appState.user?.displayName ?? "Member"
        let key = "\(uid)_\(type.rawValue)_\(groupID)_\(Int(Date().timeIntervalSince1970))"
        try? await appState.activityService.record(
            groupID: groupID, type: type, memberUid: uid, memberName: name,
            deduplicationKey: key
        )
    }
}
