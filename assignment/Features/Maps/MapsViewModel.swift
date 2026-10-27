//
//  MapsViewModel.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import SwiftUI
import MapKit
import CoreLocation

@MainActor @Observable
final class MapsViewModel {
    var cameraPosition: MapCameraPosition = .automatic
    var selectedMemberID: String?
    var isTogglingSharing = false
    var actionError: String?
    var isLocating = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var sharingMembers: [(member: GroupMember, location: SharedLocation)] {
        guard let session = appState.session else { return [] }
        return session.members.compactMap { member in
            guard member.sharingEnabled,
                  member.id != appState.uid,
                  let id = member.id,
                  let location = session.location(uid: id) else { return nil }
            return (member, location)
        }
    }

    var savedPlaces: [SavedPlace] {
        appState.session?.places ?? []
    }

    func placeMapStatus(for place: SavedPlace) -> String {
        guard place.enabled, let id = place.id else { return "Alerts off" }
        switch appState.geofenceService.presenceByPlaceID[id] {
        case .inside?: return "At \(place.name)"
        case .outside?: return "Outside \(place.name)"
        case nil:
            return appState.geofenceService.statuses[id]?.label ?? "Checking location"
        }
    }

    var selectedMemberDetail: (member: GroupMember, location: SharedLocation)? {
        guard let selectedMemberID else { return nil }
        return sharingMembers.first { $0.member.id == selectedMemberID }
    }

    func recenter() {
        let service = appState.locationService
        guard service.hasWhenInUseOrBetter else {
            if service.canRequestAuthorization {
                service.requestWhenInUseAuthorization()
                actionError = "Allow While Using the App when prompted, then tap the location button again."
            } else {
                actionError = "Location access is off. Enable it in Settings to center the map on you."
            }
            return
        }
        isLocating = true
        Task {
            defer { isLocating = false }
            do {
                let location = try await service.requestCurrentLocation()
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            } catch {
                actionError = AppError(error).message
            }
        }
    }

    func toggleSharing() async {
        isTogglingSharing = true
        defer { isTogglingSharing = false }
        do {
            try await appState.setSharing(!appState.isSharingInSelectedGroup)
        } catch {
            actionError = AppError(error).message
        }
    }
}
