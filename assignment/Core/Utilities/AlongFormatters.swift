//
//  AlongFormatters.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation

enum AlongFormatters {
    static func relativeTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) hr ago" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func fullTimestamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func dayHeader(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .complete, time: .omitted)
    }

    static func distance(_ metres: CLLocationDistance) -> String {
        if metres < 1000 { return "\(Int(metres)) m" }
        return String(format: "%.1f km", metres / 1000)
    }

    static func accuracy(_ metres: CLLocationAccuracy) -> String {
        "±\(Int(metres)) m"
    }
}

enum LocationStaleness: Equatable {
    case fresh
    case recent
    case stale
    case veryOld

    static let freshThreshold: TimeInterval = 5 * 60
    static let recentThreshold: TimeInterval = 30 * 60
    static let staleThreshold: TimeInterval = 24 * 3600

    init(updatedAt: Date, now: Date = Date()) {
        let age = now.timeIntervalSince(updatedAt)
        switch age {
        case ..<Self.freshThreshold: self = .fresh
        case ..<Self.recentThreshold: self = .recent
        case ..<Self.staleThreshold: self = .stale
        default: self = .veryOld
        }
    }

    var label: String {
        switch self {
        case .fresh: return "Live"
        case .recent: return "Recent"
        case .stale: return "Stale"
        case .veryOld: return "Outdated"
        }
    }

    var isStale: Bool { self == .stale || self == .veryOld }
}
