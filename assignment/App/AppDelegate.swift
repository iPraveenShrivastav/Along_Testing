//
//  AppDelegate.swift
//  assignment
//
//  Created by praveen on 26/10/26.
//

import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        guard FirebaseConfigurator.configureIfPossible() else {
            print("Firebase is not configured. Check GoogleService-Info.plist.")
            return true
        }

        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in

                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                    return
                }

                print("Notification permission granted: \(granted)")

                guard granted else {
                    print("Enable notifications in iPhone Settings to test pushes.")
                    return
                }

                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }

        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error retrieving FCM token: \(error.localizedDescription)")
                return
            }

            guard let token else {
                print("FCM token is nil")
                return
            }

            print("FCM REGISTRATION TOKEN:")
            print(token)

            NotificationCenter.default.post(
                name: .alongFCMTokenReceived,
                object: token
            )
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        guard FirebaseConfigurator.isConfigured else { return }

        Messaging.messaging().apnsToken = deviceToken
        print("APNs device token registered")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error.localizedDescription)")
    }
}

extension AppDelegate: MessagingDelegate {

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else {
            print("FCM registration token is nil")
            return
        }

        print("FCM REGISTRATION TOKEN:")
        print(fcmToken)

        NotificationCenter.default.post(
            name: .alongFCMTokenReceived,
            object: fcmToken
        )
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

extension Notification.Name {
    static let alongFCMTokenReceived =
        Notification.Name("alongFCMTokenReceived")
}
