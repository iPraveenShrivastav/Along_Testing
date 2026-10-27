//
//  SavedPlacesViewModel.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import SwiftUI
import CoreLocation
import UserNotifications
import MapKit

struct PlaceSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor @Observable
final class SavedPlacesViewModel {
    var name = ""
    var radius: CLLocationDistance = 200
    var latitude: Double?
    var longitude: Double?
    var selectedAddress: String?
    var addressQuery = ""
    var searchResults: [PlaceSearchResult] = []
    var isSearchingAddress = false
    var mapPosition: MapCameraPosition = .automatic
    var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 80, longitudeDelta: 120)
    )
    var monitorPlace = true
    var isGettingLocation = false
    var isWorking = false
    var errorMessage: String?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func startNewPlace() {
        name = ""
        radius = 200
        latitude = nil
        longitude = nil
        selectedAddress = nil
        addressQuery = ""
        searchResults = []
        monitorPlace = true
        errorMessage = nil
    }

    var selectedCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func updateMapRegion(_ region: MKCoordinateRegion) {
        mapRegion = region
    }

    func searchAddress() async {
        let query = addressQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isSearchingAddress else { return }
        isSearchingAddress = true
        errorMessage = nil
        defer { isSearchingAddress = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = mapRegion
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = response.mapItems.prefix(5).map { item in
                let coordinate = item.placemark.coordinate
                return PlaceSearchResult(
                    name: item.name ?? "Place",
                    address: Self.address(for: item),
                    coordinate: coordinate
                )
            }
            if searchResults.isEmpty { errorMessage = "No matching places found. Try a nearby address or landmark." }
        } catch {
            errorMessage = "Could not search that address. Check your connection and try again."
        }
    }

    func selectSearchResult(_ result: PlaceSearchResult) {
        addressQuery = result.name
        searchResults = []
        setSelectedLocation(result.coordinate, address: result.address)
    }

    func useMapCenter() async {
        let coordinate = mapRegion.center
        setSelectedLocation(coordinate, address: nil)
        selectedAddress = "Looking up address…"
        selectedAddress = await reverseAddress(for: coordinate) ?? "Pinned map location"
    }

    private func setSelectedLocation(_ coordinate: CLLocationCoordinate2D, address: String?) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        selectedAddress = address
        let span = max(0.004, min(0.04, radius / 27_000))
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        mapRegion = region
        mapPosition = .region(region)
        errorMessage = nil
    }

    private static func address(for item: MKMapItem) -> String {
        let placemark = item.placemark
        let parts = [placemark.subThoroughfare, placemark.thoroughfare,
                     placemark.locality, placemark.administrativeArea,
                     placemark.country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (item.name ?? "Selected place") : parts.joined(separator: ", ")
    }

    private func reverseAddress(for coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let places = try await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            guard let place = places.first else { return nil }
            let parts = [place.subThoroughfare, place.thoroughfare, place.locality,
                         place.administrativeArea, place.country].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } catch {
            return nil
        }
    }

    var places: [SavedPlace] {
        appState.session?.places ?? []
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        appState.locationService.authorizationStatus
    }

    var notificationAuthorizationStatus: UNAuthorizationStatus {
        appState.notificationService.authorizationStatus
    }

    var notificationsEnabled: Bool {
        appState.user?.notificationsEnabled ?? false
    }

    var needsPermissionSettings: Bool {
        locationAuthorizationStatus == .denied || locationAuthorizationStatus == .restricted ||
            !appState.locationService.servicesEnabled ||
            appState.locationService.needsAlwaysLocationSettings ||
            appState.notificationService.requiresSettings
    }

    func enableBackgroundPlaceAlerts() async {
        errorMessage = nil
        if await preparePlaceAlerts() {
            appState.reconcileGeofences()
        }
    }

    func openPermissionSettings() {
        if locationAuthorizationStatus != .authorizedAlways ||
            !appState.locationService.servicesEnabled ||
            appState.locationService.needsAlwaysLocationSettings {
            appState.locationService.openSystemSettings()
        } else {
            appState.notificationService.openSystemSettings()
        }
    }

    func status(for place: SavedPlace) -> MonitorStatus {
        guard let id = place.id else { return .savedOnly }
        let monitorStatus = appState.geofenceService.statuses[id] ?? .savedOnly
        guard place.enabled else { return .savedOnly }
        guard monitorStatus == .registered || monitorStatus == .starting else {
            return monitorStatus
        }
        guard appState.notificationService.authorizationStatus == .authorized else {
            return .requiresNotificationAuthorization
        }
        guard notificationsEnabled else { return .notificationsDisabled }
        return monitorStatus
    }

    func presenceLabel(for place: SavedPlace) -> String? {
        guard let id = place.id, place.enabled,
              appState.geofenceService.statuses[id] == .registered,
              let presence = appState.geofenceService.presenceByPlaceID[id] else { return nil }
        switch presence {
        case .inside: return "At \(place.name)"
        case .outside: return "Outside \(place.name)"
        }
    }

    func useCurrentLocation() async {
        guard !isGettingLocation else { return }
        let service = appState.locationService
        guard service.hasWhenInUseOrBetter else {
            if service.canRequestAuthorization {
                service.requestWhenInUseAuthorization()
                errorMessage = "Allow location while using Along, then tap Use my current location again."
            } else {
                service.openSystemSettings()
                errorMessage = "Allow location access in Settings, then return and try again."
            }
            return
        }

        isGettingLocation = true
        defer { isGettingLocation = false }
        do {
            let location = try await service.requestCurrentLocation()
            setSelectedLocation(location.coordinate, address: nil)
            selectedAddress = await reverseAddress(for: location.coordinate) ?? "Current location"
            errorMessage = nil
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func save() async -> Bool {
        guard !isWorking else { return false }
        errorMessage = nil
        do {
            let placeName = try Validators.placeName(name)
            guard let latitude, let longitude else {
                errorMessage = "Choose a location for this place first."
                return false
            }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            try Validators.coordinate(coordinate)
            try Validators.placeRadius(radius)
            guard let uid = appState.uid, let groupID = appState.selectedGroupID else {
                errorMessage = "Select a group first."
                return false
            }
            isWorking = true
            defer { isWorking = false }

            if monitorPlace {
                _ = await preparePlaceAlerts()
            }
            let placeID = UUID().uuidString
            _ = try await appState.groupService.createSavedPlace(
                groupID: groupID, placeID: placeID, name: placeName,
                coordinate: coordinate, radius: radius, uid: uid,
                enabled: monitorPlace
            )
            await appState.notificationService.notifyPlaceSaved(
                placeName: placeName,
                groupName: appState.selectedGroup?.name ?? "your group",
                notificationsEnabled: appState.user?.notificationsEnabled ?? false
            )
            return true
        } catch {
            errorMessage = AppError(error).message
            return false
        }
    }

    func setEnabled(_ place: SavedPlace, enabled: Bool) async {
        guard let groupID = appState.selectedGroupID, let id = place.id else { return }
        do {
            if enabled { _ = await preparePlaceAlerts() }
            try await appState.groupService.updateSavedPlace(
                groupID: groupID, placeID: id,
                name: place.name, radius: place.radius, enabled: enabled
            )
            appState.reconcileGeofences()
        } catch {
            errorMessage = AppError(error).message
        }
    }

    private func preparePlaceAlerts() async -> Bool {
        let status = await appState.requestAlwaysAuthorizationForSavedPlaces()
        guard status == .authorizedAlways else {
            errorMessage = needsPermissionSettings
                ? "Allow Always location access in Settings to monitor this place in the background."
                : "Choose Always location access to monitor this place in the background."
            return false
        }
        guard await appState.notificationService.authorizeForSavedPlaceAlerts() else {
            errorMessage = "Allow Along notifications in iOS Settings, then try again."
            return false
        }
        do {
            try await appState.enableNotificationsForSavedPlaces()
            return true
        } catch {
            errorMessage = AppError(error).message
            return false
        }
    }

    func delete(_ place: SavedPlace) async {
        guard let groupID = appState.selectedGroupID, let id = place.id else { return }
        do {
            try await appState.groupService.deleteSavedPlace(groupID: groupID, placeID: id)
            appState.reconcileGeofences()
        } catch {
            errorMessage = AppError(error).message
        }
    }
}
