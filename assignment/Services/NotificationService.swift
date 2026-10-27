//
//  NotificationService.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import UIKit
import UserNotifications

@MainActor @Observable
final class NotificationService {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var requiresSettings: Bool {
        authorizationStatus == .denied || authorizationStatus == .provisional ||
            authorizationStatus == .ephemeral
    }

    init() {
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            await refreshStatus()
            return false
        }
    }

    func notifyPlaceTransition(placeName: String, entered: Bool,
                               notificationsEnabled: Bool) async {
        await refreshStatus()
        guard notificationsEnabled, authorizationStatus == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = entered ? "At \(placeName)" : "Outside \(placeName)"
        content.body = entered
            ? "You entered the saved place area."
            : "You left the saved place area."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func notifyPlaceSaved(placeName: String, groupName: String,
                          notificationsEnabled: Bool) async {
        await refreshStatus()
        guard notificationsEnabled, authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Saved place added"
        content.body = "\(placeName) was added to \(groupName)."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "saved-place-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func authorizeForSavedPlaceAlerts() async -> Bool {
        await refreshStatus()
        switch authorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied, .provisional, .ephemeral:
            return false
        @unknown default:
            return false
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

}
