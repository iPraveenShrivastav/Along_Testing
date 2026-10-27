//
//  AppRootView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct AppRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.phase {
            case .initializing:
                initializingView
            case .unconfigured:
                unconfiguredView
            case .signedOut:
                WelcomeView()
            case .signedIn:
                MainTabView()
            }
        }
        .background(AlongTheme.Colors.background.ignoresSafeArea())
    }

    private var initializingView: some View {
        VStack(spacing: AlongTheme.Spacing.md) {
            ProgressView()
            Text("Starting Along…")
                .font(.alongCaption)
                .foregroundStyle(AlongTheme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unconfiguredView: some View {
        AlongEmptyState(
            systemImage: "gear.badge.xmark",
            title: "Firebase isn't configured",
            message: "Add GoogleService-Info.plist for bundle ID com.praveen.assignment to the app target, then rebuild. See FIREBASE_SETUP.md."
        )
    }

}
