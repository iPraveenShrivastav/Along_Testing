//
//  GroupSession.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation

@MainActor @Observable
final class GroupSession {
    let groupID: String
    let observesJoinRequests: Bool

    private(set) var members: [GroupMember] = []
    private(set) var locations: [SharedLocation] = []
    private(set) var places: [SavedPlace] = []
    private(set) var placesLoaded = false
    private(set) var events: [ActivityEvent] = []
    private(set) var joinRequests: [JoinRequest] = []
    private(set) var error: String?

    @ObservationIgnored nonisolated(unsafe) private var tasks: [Task<Void, Never>] = []

    init(groupID: String, observesJoinRequests: Bool, groupService: GroupService) {
        self.groupID = groupID
        self.observesJoinRequests = observesJoinRequests
        tasks.append(Task { [weak self] in
            do {
                for try await items in groupService.membersStream(groupID: groupID) {
                    self?.members = items
                }
            } catch { self?.error = AppError(error).message }
        })
        tasks.append(Task { [weak self] in
            do {
                for try await items in groupService.locationsStream(groupID: groupID) {
                    self?.locations = items
                }
            } catch { self?.error = AppError(error).message }
        })
        tasks.append(Task { [weak self] in
            do {
                for try await items in groupService.savedPlacesStream(groupID: groupID) {
                    self?.places = items
                    self?.placesLoaded = true
                }
            } catch { self?.error = AppError(error).message }
        })
        tasks.append(Task { [weak self] in
            do {
                for try await items in groupService.eventsStream(groupID: groupID) {
                    self?.events = items
                }
            } catch { self?.error = AppError(error).message }
        })
        if observesJoinRequests {
            tasks.append(Task { [weak self] in
                do {
                    for try await items in groupService.joinRequestsStream(groupID: groupID) {
                        self?.joinRequests = items
                    }
                } catch { self?.error = AppError(error).message }
            })
        }
    }

    func cancelTasks() {
        for task in tasks { task.cancel() }
        tasks = []
    }

    deinit {
        for task in tasks { task.cancel() }
    }

    func member(uid: String) -> GroupMember? {
        members.first { $0.id == uid }
    }

    func location(uid: String) -> SharedLocation? {
        locations.first { $0.id == uid }
    }
}
