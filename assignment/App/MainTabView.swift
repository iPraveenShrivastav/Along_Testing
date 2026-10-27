//
//  MainTabView.swift
//  assignment
//
//  Created by praveen on 26/10/26.
//

import SwiftUI


struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: Tab = .maps

    enum Tab {
        case maps
        case activity
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MapsView()
                .tabItem {
                    Label("Maps", systemImage: "map.fill")
                }
                .tag(Tab.maps)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "clock.fill")
                }
                .tag(Tab.activity)
        }
        .tint(AlongTheme.Colors.accent)
    }
}
