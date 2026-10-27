//
//  ValidatorsTests.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import XCTest
import CoreLocation
@testable import Along

@MainActor final class ValidatorsTests: XCTestCase {


    func testDisplayNameTrimsWhitespace() throws {
        XCTAssertEqual(try Validators.displayName("  Aisha  "), "Aisha")
    }

    func testEmptyDisplayNameRejected() {
        XCTAssertThrowsError(try Validators.displayName("   ")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyDisplayName)
        }
    }

    func testLongDisplayNameRejected() {
        let long = String(repeating: "a", count: 61)
        XCTAssertThrowsError(try Validators.displayName(long))
    }

    func testGroupNameTrimsAndValidates() throws {
        XCTAssertEqual(try Validators.groupName(" Family "), "Family")
        XCTAssertThrowsError(try Validators.groupName(""))
        XCTAssertThrowsError(try Validators.groupName(String(repeating: "x", count: 61)))
    }


    func testEmailValidation() throws {
        XCTAssertEqual(try Validators.email("user@example.com"), "user@example.com")
        XCTAssertThrowsError(try Validators.email("not-an-email"))
        XCTAssertThrowsError(try Validators.email("a@b"))
    }

    func testPasswordRules() throws {
        XCTAssertEqual(try Validators.password("12345678"), "12345678")
        XCTAssertThrowsError(try Validators.password("short"))
        XCTAssertThrowsError(try Validators.confirmation("abc", matches: "abd"))
        XCTAssertNoThrow(try Validators.confirmation("same", matches: "same"))
    }


    func testInviteCodeFormat() throws {
        XCTAssertEqual(try Validators.inviteCode("a1b2c3d4"), "A1B2C3D4")
        XCTAssertThrowsError(try Validators.inviteCode("SHORT"))
        XCTAssertThrowsError(try Validators.inviteCode("TOOLONGCODE"))
        XCTAssertThrowsError(try Validators.inviteCode("A1B2C3!4"))
    }


    func testCoordinateValidation() {
        XCTAssertNoThrow(try Validators.coordinate(
            CLLocationCoordinate2D(latitude: 37.33, longitude: -122.03)))
        XCTAssertThrowsError(try Validators.coordinate(
            CLLocationCoordinate2D(latitude: 91, longitude: 0)))
        XCTAssertThrowsError(try Validators.coordinate(
            CLLocationCoordinate2D(latitude: .nan, longitude: 0)))
    }

    func testShareableLocationAccuracy() {
        let good = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 10),
            altitude: 0, horizontalAccuracy: 20, verticalAccuracy: 20,
            timestamp: Date()
        )
        XCTAssertNoThrow(try Validators.shareableLocation(good))

        let bad = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 10),
            altitude: 0, horizontalAccuracy: 500, verticalAccuracy: 500,
            timestamp: Date()
        )
        XCTAssertThrowsError(try Validators.shareableLocation(bad)) { error in
            XCTAssertEqual(error as? ValidationError, .invalidAccuracy)
        }
    }

    func testRadiusBounds() {
        XCTAssertNoThrow(try Validators.placeRadius(200))
        XCTAssertThrowsError(try Validators.placeRadius(10))
        XCTAssertThrowsError(try Validators.placeRadius(10_000))
    }
}
