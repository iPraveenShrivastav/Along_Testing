//
//  ProfileViewModel.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import Foundation
import UserNotifications

@MainActor @Observable
final class ProfileViewModel {
    var displayName = ""
    var isSavingName = false
    var errorMessage: String?
    var nameSaved = false

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        displayName = appState.user?.displayName ?? ""
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    func saveDisplayName() async {
        errorMessage = nil
        nameSaved = false
        do {
            let name = try Validators.displayName(displayName)
            guard let uid = appState.uid else { return }
            isSavingName = true
            defer { isSavingName = false }
            try await appState.userService.updateDisplayName(uid: uid, displayName: name)
            nameSaved = true
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        guard let uid = appState.uid else { return }
        if enabled && appState.notificationService.authorizationStatus != .authorized {
            _ = await appState.notificationService.requestAuthorization()
        }
        await appState.notificationService.refreshStatus()
        guard appState.notificationService.authorizationStatus == .authorized || !enabled else {
            errorMessage = "Notifications are off in iOS Settings. Enable them there, then try again."
            return
        }
        do {
            try await appState.setNotificationsEnabled(enabled)
        } catch {
            errorMessage = AppError(error).message
        }
    }

    func signOut() async {
        await appState.signOut()
    }
}
