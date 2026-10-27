//
//  SavedPlace.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct SavedPlace: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: CLLocationDistance
    var createdBy: String
    var enabled: Bool
    var createdAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var region: CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radius,
            identifier: id ?? UUID().uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}

enum MonitorStatus: Equatable {
    case savedOnly
    case starting
    case registered
    case requiresAlwaysAuthorization
    case locationServicesDisabled
    case requiresNotificationAuthorization
    case notificationsDisabled
    case capacityExceeded
    case failed(String)

    var label: String {
        switch self {
        case .savedOnly: return "Saved (not monitored)"
        case .starting: return "Starting monitoring…"
        case .registered: return "Monitoring"
        case .requiresAlwaysAuthorization: return "Needs Always location"
        case .locationServicesDisabled: return "Location services off"
        case .requiresNotificationAuthorization: return "Needs notification permission"
        case .notificationsDisabled: return "Alerts off in Profile"
        case .capacityExceeded: return "Monitor limit reached"
        case .failed: return "Registration failed"
        }
    }

    var isActive: Bool { self == .registered }
}
