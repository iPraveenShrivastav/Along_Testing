//
//  GeofenceService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation

@MainActor @Observable
final class GeofenceService: NSObject {
    enum Transition { case enter, exit }
    enum Presence { case inside, outside }

    private struct CachedRegion: Codable {
        var groupID: String
        var placeID: String
        var name: String
    }

    private struct QueuedTransition {
        var regionID: String
        var transition: Transition
    }

    private let manager = CLLocationManager()

    private(set) var statuses: [String: MonitorStatus] = [:]
    private(set) var presenceByPlaceID: [String: Presence] = [:]
    private(set) var monitoredGroupID: String?

    var onTransition: ((_ placeID: String, _ placeName: String, _ groupID: String,
                        _ transition: Transition) -> Void)? {
        didSet { deliverQueuedTransitions() }
    }

    private var detailsByRegionID: [String: CachedRegion] = [:]
    private var pendingTransitions: [QueuedTransition] = []
    private let cacheKey = "along.monitoredSavedPlaces.v1"

    private let maxRegions = 20 // Core Location per-app region limit

    override init() {
        let restored: [CachedRegion]
        if let data = UserDefaults.standard.data(forKey: "along.monitoredSavedPlaces.v1"),
           let decoded = try? JSONDecoder().decode([CachedRegion].self, from: data) {
            restored = decoded
        } else {
            restored = []
        }
        super.init()
        for cached in restored {
            detailsByRegionID[cached.placeID] = cached
        }
        manager.delegate = self
    }

    func reconcile(places: [SavedPlace], groupID: String, authorization: CLAuthorizationStatus) {
        let enabled = places.filter(\.enabled)
        let withinCap = Array(enabled.prefix(maxRegions))
        let overflow = enabled.dropFirst(maxRegions)

        let desiredIDs = Set(withinCap.compactMap(\.id))
        monitoredGroupID = groupID

        for region in manager.monitoredRegions where !desiredIDs.contains(region.identifier) {
            manager.stopMonitoring(for: region)
            detailsByRegionID.removeValue(forKey: region.identifier)
            presenceByPlaceID.removeValue(forKey: region.identifier)
        }
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            var unavailableStatuses: [String: MonitorStatus] = Dictionary(uniqueKeysWithValues: withinCap.compactMap { place in
                place.id.map { ($0, .locationServicesDisabled) }
            })
            for place in overflow {
                if let id = place.id { unavailableStatuses[id] = .capacityExceeded }
            }
            for region in manager.monitoredRegions {
                manager.stopMonitoring(for: region)
            }
            detailsByRegionID.removeAll()
            statuses = unavailableStatuses
            persistRegionCache()
            return
        }

        if authorization != .authorizedAlways {
            for region in manager.monitoredRegions where desiredIDs.contains(region.identifier) {
                manager.stopMonitoring(for: region)
                detailsByRegionID.removeValue(forKey: region.identifier)
                presenceByPlaceID.removeValue(forKey: region.identifier)
            }
        }

        var newStatuses: [String: MonitorStatus] = [:]
        for place in overflow {
            if let id = place.id { newStatuses[id] = .capacityExceeded }
        }

        for place in withinCap {
            guard let id = place.id else { continue }
            switch authorization {
            case .authorizedAlways:
                detailsByRegionID[id] = CachedRegion(
                    groupID: groupID, placeID: id, name: place.name
                )
                if manager.monitoredRegions.contains(where: { $0.identifier == id }) {
                    newStatuses[id] = .registered
                    if let region = manager.monitoredRegions.first(where: { $0.identifier == id }) {
                        manager.requestState(for: region)
                    }
                } else {
                    manager.startMonitoring(for: place.region)
                    newStatuses[id] = .starting
                }
            case .authorizedWhenInUse:
                newStatuses[id] = .requiresAlwaysAuthorization
            case .notDetermined:
                newStatuses[id] = .requiresAlwaysAuthorization
            case .denied, .restricted:
                newStatuses[id] = .locationServicesDisabled
            @unknown default:
                newStatuses[id] = .savedOnly
            }
        }
        for place in places where !place.enabled {
            if let id = place.id {
                newStatuses[id] = .savedOnly
                detailsByRegionID.removeValue(forKey: id)
                presenceByPlaceID.removeValue(forKey: id)
            }
        }
        statuses = newStatuses
        persistRegionCache()
    }

    func stopAll() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        detailsByRegionID.removeAll()
        statuses.removeAll()
        presenceByPlaceID.removeAll()
        monitoredGroupID = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }


    fileprivate func handleTransition(regionID: String, transition: Transition) {
        guard detailsByRegionID[regionID] != nil else { return }
        presenceByPlaceID[regionID] = transition == .enter ? .inside : .outside
        if let onTransition {
            deliver(regionID: regionID, transition: transition, using: onTransition)
        } else {
            pendingTransitions.append(QueuedTransition(regionID: regionID, transition: transition))
        }
    }

    fileprivate func handleMonitoringFailed(regionID: String, error: Error) {
        statuses[regionID] = .failed(error.localizedDescription)
    }

    fileprivate func handleMonitoringStarted(regionID: String) {
        guard detailsByRegionID[regionID] != nil else { return }
        statuses[regionID] = .registered
        if let region = manager.monitoredRegions.first(where: { $0.identifier == regionID }) {
            manager.requestState(for: region)
        }
    }

    fileprivate func handleDeterminedState(regionID: String, state: CLRegionState) {
        guard detailsByRegionID[regionID] != nil else { return }
        switch state {
        case .inside: presenceByPlaceID[regionID] = .inside
        case .outside: presenceByPlaceID[regionID] = .outside
        case .unknown: break
        @unknown default: break
        }
    }

    private func deliverQueuedTransitions() {
        guard let onTransition, !pendingTransitions.isEmpty else { return }
        let queued = pendingTransitions
        pendingTransitions.removeAll()
        for event in queued {
            deliver(regionID: event.regionID, transition: event.transition, using: onTransition)
        }
    }

    private func deliver(
        regionID: String,
        transition: Transition,
        using handler: (String, String, String, Transition) -> Void
    ) {
        guard let details = detailsByRegionID[regionID] else { return }
        handler(details.placeID, details.name, details.groupID, transition)
    }

    private func persistRegionCache() {
        if let data = try? JSONEncoder().encode(Array(detailsByRegionID.values)) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

extension GeofenceService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleMonitoringStarted(regionID: id) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleTransition(regionID: id, transition: .enter) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleTransition(regionID: id, transition: .exit) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handleDeterminedState(regionID: id, state: state) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard let id = region?.identifier else { return }
        Task { @MainActor in self.handleMonitoringFailed(regionID: id, error: error) }
    }
}
