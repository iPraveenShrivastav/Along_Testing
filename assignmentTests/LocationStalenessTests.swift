//
//  LocationStalenessTests.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import XCTest
@testable import Along

@MainActor final class LocationStalenessTests: XCTestCase {

    func testFreshClassification() {
        let now = Date()
        let twoMinutesAgo = now.addingTimeInterval(-120)
        XCTAssertEqual(LocationStaleness(updatedAt: twoMinutesAgo, now: now), .fresh)
    }

    func testRecentClassification() {
        let now = Date()
        let tenMinutesAgo = now.addingTimeInterval(-600)
        XCTAssertEqual(LocationStaleness(updatedAt: tenMinutesAgo, now: now), .recent)
    }

    func testStaleClassification() {
        let now = Date()
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let stale = LocationStaleness(updatedAt: twoHoursAgo, now: now)
        XCTAssertEqual(stale, .stale)
        XCTAssertTrue(stale.isStale)
    }

    func testVeryOldClassification() {
        let now = Date()
        let twoDaysAgo = now.addingTimeInterval(-172800)
        let old = LocationStaleness(updatedAt: twoDaysAgo, now: now)
        XCTAssertEqual(old, .veryOld)
        XCTAssertTrue(old.isStale)
    }
}
