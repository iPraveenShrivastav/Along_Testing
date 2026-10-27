//
//  AlongApp.swift
//  assignment
//
//  Created by praveen on 26/10/26.
//

import SwiftUI

@main
struct AlongApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appState)
                .task { appState.start() }
        }
    }
}
