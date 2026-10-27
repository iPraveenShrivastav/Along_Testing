//
//  Validators.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import CoreLocation

enum ValidationError: LocalizedError, Equatable {
    case emptyDisplayName
    case displayNameTooLong
    case emptyGroupName
    case groupNameTooLong
    case invalidEmail
    case passwordTooShort
    case passwordsDoNotMatch
    case invalidCoordinate
    case invalidAccuracy
    case radiusOutOfRange(min: Double, max: Double)
    case emptyPlaceName

    var errorDescription: String? {
        switch self {
        case .emptyDisplayName: return "Please enter a display name."
        case .displayNameTooLong: return "Display name must be 60 characters or fewer."
        case .emptyGroupName: return "Please enter a group name."
        case .groupNameTooLong: return "Group name must be 60 characters or fewer."
        case .invalidEmail: return "Please enter a valid email address."
        case .passwordTooShort: return "Password must be at least 8 characters."
        case .passwordsDoNotMatch: return "Passwords do not match."
        case .invalidCoordinate: return "That location isn't valid. Please pick a point on the map."
        case .invalidAccuracy: return "Location accuracy is too low to share right now. Try again in a moment."
        case .radiusOutOfRange(let min, let max):
            return "Radius must be between \(Int(min)) and \(Int(max)) metres."
        case .emptyPlaceName: return "Please give this place a name."
        }
    }
}

enum Validators {
    static let maxNameLength = 60
    static let minPasswordLength = 8
    static let minPlaceRadius: CLLocationDistance = 50
    static let maxPlaceRadius: CLLocationDistance = 2000

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    static func displayName(_ value: String) throws -> String {
        let name = trimmed(value)
        if name.isEmpty { throw ValidationError.emptyDisplayName }
        if name.count > maxNameLength { throw ValidationError.displayNameTooLong }
        return name
    }

    @discardableResult
    static func groupName(_ value: String) throws -> String {
        let name = trimmed(value)
        if name.isEmpty { throw ValidationError.emptyGroupName }
        if name.count > maxNameLength { throw ValidationError.groupNameTooLong }
        return name
    }

    static func email(_ value: String) throws -> String {
        let email = trimmed(value)
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard email.range(of: pattern, options: .regularExpression) != nil else {
            throw ValidationError.invalidEmail
        }
        return email
    }

    static func suggestedDisplayName(fromEmail value: String) -> String {
        let localPart = value.split(separator: "@", maxSplits: 1).first.map { address in
            String(address.split(separator: "+", maxSplits: 1).first ?? address)
        } ?? ""
        let words = localPart
            .split { !$0.isLetter && !$0.isNumber }
            .map { String($0).capitalized }
            .joined(separator: " ")
        let name = words.isEmpty ? "Along User" : words
        return String(name.prefix(maxNameLength))
    }

    static func password(_ value: String) throws -> String {
        guard value.count >= minPasswordLength else { throw ValidationError.passwordTooShort }
        return value
    }

    static func confirmation(_ value: String, matches password: String) throws {
        guard value == password else { throw ValidationError.passwordsDoNotMatch }
    }

    static func coordinate(_ coordinate: CLLocationCoordinate2D) throws {
        guard CLLocationCoordinate2DIsValid(coordinate),
              abs(coordinate.latitude) <= 90,
              abs(coordinate.longitude) <= 180 else {
            throw ValidationError.invalidCoordinate
        }
    }

    static func shareableLocation(_ location: CLLocation) throws {
        try coordinate(location.coordinate)
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 else {
            throw ValidationError.invalidAccuracy
        }
    }

    static func placeRadius(_ radius: CLLocationDistance) throws {
        guard (minPlaceRadius...maxPlaceRadius).contains(radius) else {
            throw ValidationError.radiusOutOfRange(min: minPlaceRadius, max: maxPlaceRadius)
        }
    }

    static func placeName(_ value: String) throws -> String {
        let name = trimmed(value)
        if name.isEmpty { throw ValidationError.emptyPlaceName }
        if name.count > maxNameLength { throw ValidationError.displayNameTooLong }
        return name
    }
}
