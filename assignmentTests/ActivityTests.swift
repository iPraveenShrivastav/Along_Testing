//
//  ActivityTests.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import XCTest
@testable import Along

@MainActor final class ActivityTests: XCTestCase {

    func testDeduplicationKeyStableWithinSameMinute() {
        let t = Date(timeIntervalSince1970: 1_700_000_040)
        let k1 = ActivityService.deduplicationKey(
            memberUid: "u1", placeId: "p1", type: .arrived, at: t)
        let k2 = ActivityService.deduplicationKey(
            memberUid: "u1", placeId: "p1", type: .arrived, at: t.addingTimeInterval(20))
        XCTAssertEqual(k1, k2, "Two deliveries inside one minute must collapse")
    }

    func testDeduplicationKeyDiffersAcrossMinutesAndTypes() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let arrive = ActivityService.deduplicationKey(
            memberUid: "u1", placeId: "p1", type: .arrived, at: t)
        let depart = ActivityService.deduplicationKey(
            memberUid: "u1", placeId: "p1", type: .departed, at: t)
        let later = ActivityService.deduplicationKey(
            memberUid: "u1", placeId: "p1", type: .arrived, at: t.addingTimeInterval(61))
        XCTAssertNotEqual(arrive, depart)
        XCTAssertNotEqual(arrive, later)
    }

    func testEventOrderingSortsByTimestampDesc() {
        let now = Date()
        let events = [
            ActivityEvent(id: "a", type: .arrived, memberUid: "u", memberName: "A",
                          timestamp: now.addingTimeInterval(-300),
                          source: .device, deduplicationKey: "a"),
            ActivityEvent(id: "b", type: .departed, memberUid: "u", memberName: "A",
                          timestamp: now.addingTimeInterval(-60),
                          source: .device, deduplicationKey: "b"),
            ActivityEvent(id: "c", type: .memberJoined, memberUid: "u", memberName: "A",
                          timestamp: now.addingTimeInterval(-600),
                          source: .server, deduplicationKey: "c"),
        ]
        let sorted = events.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        XCTAssertEqual(sorted.map(\.id), ["b", "a", "c"])
    }

    func testEventSummaryIncludesPlace() {
        let event = ActivityEvent(id: "x", type: .arrived, memberUid: "u",
                                  memberName: "Ravi", placeId: "p", placeName: "Home",
                                  timestamp: Date(), source: .device,
                                  deduplicationKey: "x")
        XCTAssertEqual(event.summary, "Ravi arrived at Home")
    }
}
