//
//  AppState.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor @Observable
final class AppState {
    enum Phase: Equatable {
        case initializing
        case unconfigured
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .initializing
    private(set) var user: AlongUser?
    private(set) var uid: String?
    private(set) var groups: [AlongGroup] = []
    private(set) var session: GroupSession?
    private(set) var startupError: String?
    private(set) var sharingGroupIDs: Set<String> = []

    var selectedGroupID: String? {
        didSet { rebuildSession() }
    }

    let authService = AuthService()
    let userService = UserService()
    let groupService = GroupService()
    let locationService = LocationService()
    let geofenceService = GeofenceService()
    let activityService = ActivityService()
    let notificationService = NotificationService()

    private var profileTask: Task<Void, Never>?
    private var groupsTask: Task<Void, Never>?
    private var memberFetchTask: Task<Void, Never>?
    private var fcmObserver: NSObjectProtocol?
    private var pendingRegionTransitions: [(String, String, String, GeofenceService.Transition)] = []

    private var lastLocationWriteAt: Date?
    private var lastWrittenLocation: CLLocation?
    private let minWriteInterval: TimeInterval = 15
    private let minWriteDistance: CLLocationDistance = 25

    var selectedGroup: AlongGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    var isSharingInSelectedGroup: Bool {
        guard let selectedGroupID else { return false }
        return sharingGroupIDs.contains(selectedGroupID)
    }

    var myMember: GroupMember? {
        guard let uid else { return nil }
        return session?.member(uid: uid)
    }

    func start() {
        guard FirebaseConfigurator.isConfigured else {
            phase = .unconfigured
            return
        }
        locationService.onLocation = { [weak self] location in
            self?.handleLocationUpdate(location)
        }
        geofenceService.onTransition = { [weak self] placeID, placeName, groupID, transition in
            self?.handleRegionTransition(
                placeID: placeID, placeName: placeName,
                groupID: groupID, transition: transition
            )
        }
        fcmObserver = NotificationCenter.default.addObserver(
            forName: .alongFCMTokenReceived, object: nil, queue: .main
        ) { [weak self] notification in
            let token = notification.object as? String
            Task { @MainActor [weak self] in
                guard let self, let token, let uid = self.uid else { return }
                try? await self.userService.addFCMToken(uid: uid, token: token)
            }
        }
        authService.startListening { [weak self] firebaseUser in
            guard let self else { return }
            self.handleAuthChange(firebaseUser)
        }
    }


    private func handleAuthChange(_ firebaseUser: User?) {
        guard let firebaseUser else {
            teardownSignedInState()
            phase = .signedOut
            return
        }
        if uid == firebaseUser.uid { return }
        uid = firebaseUser.uid
        phase = .signedIn
        let email = firebaseUser.email ?? ""
        let name = "Along User"
        Task {
            do {
                let profile = try await userService.ensureProfile(
                    uid: firebaseUser.uid, email: email, displayName: name
                )
                user = profile
                flushPendingRegionTransitions()
                startupError = nil
            } catch {
                startupError = AppError(error).message
            }
            startProfileObservation(uid: firebaseUser.uid)
            startGroupsObservation(uid: firebaseUser.uid)
        }
    }

    private func startProfileObservation(uid: String) {
        profileTask?.cancel()
        profileTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await profile in self.userService.profileStream(uid: uid) {
                    if let profile {
                        self.user = profile
                        self.flushPendingRegionTransitions()
                        self.reconcileGeofences()
                    }
                }
            } catch {  }
        }
    }

    private func startGroupsObservation(uid: String) {
        groupsTask?.cancel()
        groupsTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await groups in self.groupService.myGroupsStream(uid: uid) {
                    self.groups = groups
                    if let selected = self.selectedGroupID,
                       !groups.contains(where: { $0.id == selected }) {
                        self.selectedGroupID = nil
                    }
                    if self.selectedGroupID == nil {
                        self.selectedGroupID = groups.first?.id
                    }
                    if let selectedID = self.selectedGroupID,
                       self.session?.groupID == selectedID,
                       let selectedGroup = groups.first(where: { $0.id == selectedID }),
                       let uid = self.uid,
                       self.session?.observesJoinRequests != (selectedGroup.createdBy == uid) {
                        self.rebuildSession()
                    }
                    self.refreshSharingStatus(groups: groups, uid: uid)
                }
            } catch {
                self.startupError = AppError(error).message
            }
        }
    }

    private func refreshSharingStatus(groups: [AlongGroup], uid: String) {
        memberFetchTask?.cancel()
        memberFetchTask = Task { [weak self] in
            var enabled: Set<String> = []
            for group in groups {
                guard let id = group.id else { continue }
                let doc = try? await Firestore.firestore()
                    .collection("groups").document(id)
                    .collection("members").document(uid).getDocument()
                if (doc?.data()?["sharingEnabled"] as? Bool) == true {
                    enabled.insert(id)
                }
            }
            guard !Task.isCancelled else { return }
            self?.sharingGroupIDs = enabled
            if enabled.isEmpty {
                self?.locationService.stopUpdating()
            } else if self?.locationService.hasWhenInUseOrBetter == true {
                self?.locationService.startUpdating(backgroundAllowed: true)
            }
        }
    }

    private func rebuildSession() {
        session?.cancelTasks()
        guard let selectedGroupID, let uid else {
            session = nil
            geofenceService.stopAll()
            return
        }
        let observesJoinRequests = groups.first(where: { $0.id == selectedGroupID })?.createdBy == uid
        session = GroupSession(
            groupID: selectedGroupID,
            observesJoinRequests: observesJoinRequests,
            groupService: groupService
        )
    }


    func setSharing(_ enabled: Bool) async throws {
        guard let uid, let groupID = selectedGroupID else { return }
        if enabled && !locationService.hasWhenInUseOrBetter {
            if locationService.canRequestAuthorization {
                locationService.requestWhenInUseAuthorization()
                throw AppError("Allow While Using the App when prompted, then turn on sharing again.")
            }
            throw AppError("Location access is off. Enable it in Settings before turning on sharing.")
        }
        try await groupService.setSharing(groupID: groupID, uid: uid, enabled: enabled)
        if enabled {
            sharingGroupIDs.insert(groupID)
            locationService.startUpdating(backgroundAllowed: true)
            await recordEventBestEffort(type: .sharingStarted, groupID: groupID)
        } else {
            sharingGroupIDs.remove(groupID)
            if sharingGroupIDs.isEmpty {
                locationService.stopUpdating()
            }
            await recordEventBestEffort(type: .sharingPaused, groupID: groupID)
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        guard !sharingGroupIDs.isEmpty, let uid else { return }
        if let lastAt = lastLocationWriteAt,
           Date().timeIntervalSince(lastAt) < minWriteInterval,
           let lastLoc = lastWrittenLocation,
           location.distance(from: lastLoc) < minWriteDistance {
            return
        }
        lastLocationWriteAt = Date()
        lastWrittenLocation = location
        for groupID in sharingGroupIDs {
            Task {
                try? await groupService.writeLocation(groupID: groupID, uid: uid, location: location)
            }
        }
    }


    func reconcileGeofences() {
        guard let groupID = selectedGroupID,
              let session,
              session.groupID == groupID,
              session.placesLoaded else { return }
        geofenceService.reconcile(
            places: session.places,
            groupID: groupID,
            authorization: locationService.authorizationStatus
        )
    }

    func setNotificationsEnabled(_ enabled: Bool) async throws {
        guard let uid else { return }
        try await userService.setNotificationsEnabled(uid: uid, enabled: enabled)
        if var user {
            user.notificationsEnabled = enabled
            self.user = user
        }
    }

    func enableNotificationsForSavedPlaces() async throws {
        try await setNotificationsEnabled(true)
    }

    func requestAlwaysAuthorizationForSavedPlaces() async -> CLAuthorizationStatus {
        await locationService.requestAlwaysAuthorizationForSavedPlaces()
    }

    private func handleRegionTransition(placeID: String, placeName: String, groupID: String,
                                        transition: GeofenceService.Transition) {
        guard let uid, user != nil else {
            pendingRegionTransitions.append((placeID, placeName, groupID, transition))
            return
        }
        let type: ActivityEventType = transition == .enter ? .arrived : .departed
        let name = user?.displayName ?? "Member"
        let key = ActivityService.deduplicationKey(
            memberUid: uid, placeId: placeID, type: type
        )
        Task {
            await notificationService.notifyPlaceTransition(
                placeName: placeName,
                entered: transition == .enter,
                notificationsEnabled: user?.notificationsEnabled ?? false
            )
        }
        Task {
            try? await activityService.record(
                groupID: groupID, type: type, memberUid: uid, memberName: name,
                placeId: placeID, placeName: placeName, deduplicationKey: key
            )
        }
    }

    private func flushPendingRegionTransitions() {
        guard uid != nil, user != nil, !pendingRegionTransitions.isEmpty else { return }
        let queued = pendingRegionTransitions
        pendingRegionTransitions.removeAll()
        for (placeID, placeName, groupID, transition) in queued {
            handleRegionTransition(
                placeID: placeID, placeName: placeName,
                groupID: groupID, transition: transition
            )
        }
    }

    private func recordEventBestEffort(type: ActivityEventType, groupID: String) async {
        guard let uid else { return }
        let name = user?.displayName ?? "Member"
        let key = "\(uid)_\(type.rawValue)_\(Int(Date().timeIntervalSince1970 / 60))"
        try? await activityService.record(
            groupID: groupID, type: type, memberUid: uid, memberName: name,
            deduplicationKey: key
        )
    }


    private func handleFCMToken(_ token: String) {
        guard let uid else { return }
        Task { try? await userService.addFCMToken(uid: uid, token: token) }
    }


    func signOut() async {
        if let uid {
            for groupID in sharingGroupIDs {
                try? await groupService.setSharing(groupID: groupID, uid: uid, enabled: false)
            }
        }
        teardownSignedInState()
        try? authService.signOut()
        phase = .signedOut
    }

    private func teardownSignedInState() {
        locationService.stopUpdating()
        geofenceService.stopAll()
        profileTask?.cancel()
        groupsTask?.cancel()
        memberFetchTask?.cancel()
        session?.cancelTasks()
        session = nil
        groups = []
        sharingGroupIDs = []
        pendingRegionTransitions.removeAll()
        selectedGroupID = nil
        user = nil
        uid = nil
        lastLocationWriteAt = nil
        lastWrittenLocation = nil
    }
}
