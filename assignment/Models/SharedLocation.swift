//
//  SharedLocation.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct SharedLocation: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var updatedAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var staleness: LocationStaleness {
        guard let updatedAt else { return .veryOld }
        return LocationStaleness(updatedAt: updatedAt)
    }
}
