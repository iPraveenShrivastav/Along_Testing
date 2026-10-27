//
//  LocationService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation
import UIKit

@MainActor @Observable
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private let oneShotManager = CLLocationManager()

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?
    private(set) var lastError: String?
    private(set) var isUpdating = false
    private(set) var accuracyReduced = false

    var onLocation: ((CLLocation) -> Void)?

    private var oneShotContinuations: [CheckedContinuation<CLLocation, Error>] = []
    private var oneShotTimeoutTask: Task<Void, Never>?
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private let didRequestAlwaysKey = "along.didRequestAlwaysLocationAuthorization"

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25
        oneShotManager.delegate = self
        oneShotManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        oneShotManager.distanceFilter = kCLDistanceFilterNone
    }

    var servicesEnabled: Bool {
        authorizationStatus != .denied && authorizationStatus != .restricted
    }

    var canRequestAuthorization: Bool { authorizationStatus == .notDetermined }

    var hasWhenInUseOrBetter: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var hasAlways: Bool { authorizationStatus == .authorizedAlways }

    var needsAlwaysLocationSettings: Bool {
        authorizationStatus != .authorizedAlways &&
            authorizationStatus != .denied && authorizationStatus != .restricted &&
            UserDefaults.standard.bool(forKey: didRequestAlwaysKey)
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorizationForSavedPlaces() async -> CLAuthorizationStatus {
        switch authorizationStatus {
        case .authorizedAlways, .denied, .restricted:
            return authorizationStatus
        case .notDetermined:
            guard !UserDefaults.standard.bool(forKey: didRequestAlwaysKey) else {
                return authorizationStatus
            }
            UserDefaults.standard.set(true, forKey: didRequestAlwaysKey)
            return await requestAuthorizationChange {
                manager.requestAlwaysAuthorization()
            }
        case .authorizedWhenInUse:
            return await requestAlwaysUpgradeIfAvailable()
        @unknown default:
            return authorizationStatus
        }
    }

    private func requestAlwaysUpgradeIfAvailable() async -> CLAuthorizationStatus {
        guard !UserDefaults.standard.bool(forKey: didRequestAlwaysKey) else {
            return authorizationStatus
        }
        UserDefaults.standard.set(true, forKey: didRequestAlwaysKey)
        return await requestAuthorizationChange {
            manager.requestAlwaysAuthorization()
        }
    }

    private func requestAuthorizationChange(
        _ request: () -> Void
    ) async -> CLAuthorizationStatus {
        guard authorizationContinuation == nil else { return authorizationStatus }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            request()
        }
    }

    func requestCurrentLocation() async throws -> CLLocation {
        guard hasWhenInUseOrBetter else {
            throw AppError("Location permission is required to show your position.")
        }
        if let lastLocation, isUsable(lastLocation, maxAge: 15) {
            return lastLocation
        }
        return try await withCheckedThrowingContinuation { continuation in
            let shouldStartRequest = oneShotContinuations.isEmpty
            oneShotContinuations.append(continuation)
            guard shouldStartRequest else { return }

            oneShotManager.requestLocation()
            oneShotTimeoutTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch {
                    return
                }
                self?.expireOneShotRequest()
            }
        }
    }

    func startUpdating(backgroundAllowed: Bool) {
        guard hasWhenInUseOrBetter else { return }
        manager.allowsBackgroundLocationUpdates = backgroundAllowed
        guard !isUpdating else { return }
        isUpdating = true
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        if isUpdating {
            isUpdating = false
            manager.stopUpdatingLocation()
        }
        manager.allowsBackgroundLocationUpdates = false
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }


    fileprivate func handleLocations(_ locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        lastLocation = newest
        lastError = nil
        onLocation?(newest)
    }

    fileprivate func handleOneShotLocations(_ locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        guard isUsable(newest, maxAge: 30) else {
            finishOneShot(.failure(AppError(
                "The location result was too old or too imprecise. Please try again."
            )))
            return
        }
        lastLocation = newest
        lastError = nil
        finishOneShot(.success(newest))
    }

    fileprivate func handleFailure(_ error: Error) {
        lastError = (error as? CLError).flatMap { describe($0) } ?? error.localizedDescription
    }

    fileprivate func handleOneShotFailure(_ error: Error) {
        lastError = (error as? CLError).flatMap { describe($0) } ?? error.localizedDescription
        finishOneShot(.failure(AppError(lastError ?? "Location request failed.")))
    }

    fileprivate func handleAuthorizationChange() {
        authorizationStatus = manager.authorizationStatus
        accuracyReduced = manager.accuracyAuthorization == .reducedAccuracy
        if authorizationStatus != .notDetermined,
           let continuation = authorizationContinuation {
            authorizationContinuation = nil
            continuation.resume(returning: authorizationStatus)
        }
        if !hasWhenInUseOrBetter {
            if !oneShotContinuations.isEmpty {
                finishOneShot(.failure(AppError(
                    "Location access is off for Along. Enable it in Settings and try again."
                )))
            }
            stopUpdating()
            lastLocation = nil
        }
    }

    private func finishOneShot(_ result: Result<CLLocation, Error>) {
        guard !oneShotContinuations.isEmpty else { return }
        let continuations = oneShotContinuations
        oneShotContinuations.removeAll()
        oneShotTimeoutTask?.cancel()
        oneShotTimeoutTask = nil
        for continuation in continuations {
            continuation.resume(with: result)
        }
    }

    private func expireOneShotRequest() {
        guard !oneShotContinuations.isEmpty else { return }
        finishOneShot(.failure(AppError(
            "Along couldn't get a location fix. Check that Location Services are on, move near a window or outdoors, and try again."
        )))
        oneShotManager.stopUpdatingLocation()
    }

    private func isUsable(_ location: CLLocation, maxAge: TimeInterval) -> Bool {
        let age = Date().timeIntervalSince(location.timestamp)
        return age >= -5 && age <= maxAge &&
            location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 100
    }

    private func describe(_ error: CLError) -> String {
        switch error.code {
        case .denied: return "Location access is off for Along. Enable it in Settings to share your position."
        case .locationUnknown: return "Your location couldn't be determined right now."
        case .network: return "A network error prevented a location fix."
        default: return "Location error: \(error.localizedDescription)"
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if manager === self.oneShotManager {
                self.handleOneShotLocations(locations)
            } else {
                self.handleLocations(locations)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if manager === self.oneShotManager {
                self.handleOneShotFailure(error)
            } else {
                self.handleFailure(error)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.handleAuthorizationChange() }
    }
}
