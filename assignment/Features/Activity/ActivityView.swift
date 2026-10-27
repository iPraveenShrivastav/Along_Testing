//
//  ActivityView.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct ActivityView: View {
    @Environment(AppState.self) private var appState

    private var sections: [(title: String, events: [ActivityEvent])] {
        let events = appState.session?.events ?? []
        var result: [(String, [ActivityEvent])] = []
        for event in events {
            let day = AlongFormatters.dayHeader(event.timestamp ?? Date())
            if let last = result.last, last.0 == day {
                result[result.count - 1].1.append(event)
            } else {
                result.append((day, [event]))
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.selectedGroupID == nil || appState.groups.isEmpty {
                    AlongEmptyState(
                        systemImage: "clock",
                        title: "No activity yet",
                        message: "Join or create a group, then arrivals, departures and membership changes will appear here."
                    )
                } else if sections.isEmpty {
                    AlongEmptyState(
                        systemImage: "clock",
                        title: "Nothing yet",
                        message: "Events like arrivals at saved places will show up here once they happen."
                    )
                } else {
                    List {
                        if let error = appState.session?.error {
                            Section {
                                AlongErrorBanner(message: error)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        ForEach(sections, id: \.title) { section in
                            Section {
                                ForEach(section.events) { event in
                                    ActivityRow(event: event)
                                }
                            } header: {
                                Text(section.title)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle(appState.selectedGroup?.name ?? "Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ActivityRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: AlongTheme.Spacing.md) {
            Image(systemName: event.type.systemImage)
                .font(.title3)
                .foregroundStyle(AlongTheme.Colors.accent)
                .frame(width: 36, height: 36)
                .background(AlongTheme.Colors.accentSoft, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.summary)
                    .font(.alongBody)
                    .foregroundStyle(AlongTheme.Colors.primaryText)
                if let timestamp = event.timestamp {
                    Text(AlongFormatters.relativeTimestamp(timestamp))
                        .font(.alongCaption)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
