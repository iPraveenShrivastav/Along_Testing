//
//  SavedPlacesSheet.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI
import CoreLocation
import MapKit

struct SavedPlacesSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SavedPlacesViewModel?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.selectedGroupID == nil {
                    AlongEmptyState(
                        systemImage: "mappin.and.ellipse",
                        title: "No group selected",
                        message: "Saved places belong to a group. Select or create a group first."
                    )
                } else if (viewModel?.places ?? []).isEmpty {
                    AlongEmptyState(
                        systemImage: "mappin.and.ellipse",
                        title: "No saved places",
                        message: "Add places like home or school to log arrivals and departures for this group.",
                        actionTitle: "Add Place"
                    ) { showAdd = true }
                } else {
                    List {
                        if let error = viewModel?.errorMessage {
                            Section { AlongErrorBanner(message: error) }
                        }
                        backgroundAlertsSection
                        ForEach(viewModel?.places ?? []) { place in
                            placeRow(place)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Saved Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(appState.selectedGroupID == nil)
                    .accessibilityLabel("Add saved place")
                }
            }
            .sheet(isPresented: $showAdd) {
                if let viewModel {
                    AddPlaceView(viewModel: viewModel)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .onChange(of: showAdd) { _, isPresented in
                if isPresented { viewModel?.startNewPlace() }
            }
            .onAppear {
                if viewModel == nil { viewModel = SavedPlacesViewModel(appState: appState) }
            }
        }
    }

    @ViewBuilder
    private var backgroundAlertsSection: some View {
        if let viewModel, !viewModel.places.filter(\.enabled).isEmpty,
           (viewModel.locationAuthorizationStatus != .authorizedAlways ||
            viewModel.notificationAuthorizationStatus != .authorized ||
            !viewModel.notificationsEnabled) {
            Section {
                VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
                    Text("Arrival and departure alerts")
                        .font(.alongHeadline)
                    Text("Enable this on your device to receive arrival and departure alerts for active saved places. Along may ask for Always location access for background group events, and iOS will ask separately about notifications.")
                        .font(.alongCaption)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                    if let error = viewModel.errorMessage {
                        AlongErrorBanner(message: error)
                    }
                    Button("Finish alert setup") {
                        Task { await viewModel.enableBackgroundPlaceAlerts() }
                    }
                    .font(.alongCaption.weight(.semibold))
                    .foregroundStyle(AlongTheme.Colors.accent)
                    if viewModel.needsPermissionSettings {
                        Button("Open Settings") { viewModel.openPermissionSettings() }
                            .font(.alongCaption.weight(.semibold))
                            .foregroundStyle(AlongTheme.Colors.accent)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func placeRow(_ place: SavedPlace) -> some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.alongHeadline)
                        .foregroundStyle(AlongTheme.Colors.primaryText)
                    Text("Radius \(AlongFormatters.distance(place.radius))")
                        .font(.alongCaption)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { place.enabled },
                    set: { newValue in
                        Task { await viewModel?.setEnabled(place, enabled: newValue) }
                    }
                ))
                .labelsHidden()
                .accessibilityLabel("Monitor \(place.name)")
            }
            if place.enabled {
                let status = viewModel?.status(for: place) ?? .savedOnly
                let presence = viewModel?.presenceLabel(for: place)
                if let presence {
                    AlongStatusPill(text: presence, tone: .active)
                }
                if presence == nil || status != .registered {
                    AlongStatusPill(
                        text: status.label,
                        tone: status.isActive ? .active : (status == .savedOnly ? .neutral : .warning)
                    )
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) {
                Task { await viewModel?.delete(place) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddPlaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SavedPlacesViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AlongTheme.Spacing.md) {
                    AlongFormField(title: "Name", text: $viewModel.name,
                                   placeholder: "e.g. Home, School, Gym")

                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
                        Text("Location")
                            .font(.alongCaption.weight(.medium))
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                        HStack(spacing: AlongTheme.Spacing.xs) {
                            TextField("Search address or place", text: $viewModel.addressQuery)
                                .textFieldStyle(.roundedBorder)
                                .submitLabel(.search)
                                .onSubmit { Task { await viewModel.searchAddress() } }
                            Button {
                                Task { await viewModel.searchAddress() }
                            } label: {
                                if viewModel.isSearchingAddress { ProgressView() }
                                else { Image(systemName: "magnifyingglass") }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AlongTheme.Colors.accent)
                            .disabled(viewModel.addressQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSearchingAddress)
                            .accessibilityLabel("Search address")
                        }

                        if !viewModel.searchResults.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(viewModel.searchResults) { result in
                                    Button {
                                        viewModel.selectSearchResult(result)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.name)
                                                .font(.alongBody.weight(.medium))
                                                .foregroundStyle(AlongTheme.Colors.primaryText)
                                            Text(result.address)
                                                .font(.alongCaption)
                                                .foregroundStyle(AlongTheme.Colors.secondaryText)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 9)
                                    }
                                    if result.id != viewModel.searchResults.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .background(AlongTheme.Colors.card, in: RoundedRectangle(cornerRadius: AlongTheme.Radius.small))
                        }

                        AlongCard {
                            VStack(alignment: .leading, spacing: AlongTheme.Spacing.sm) {
                                MapReader { _ in
                                    Map(position: $viewModel.mapPosition) {
                                        if let coordinate = viewModel.selectedCoordinate {
                                            MapCircle(center: coordinate, radius: viewModel.radius)
                                                .foregroundStyle(AlongTheme.Colors.accent.opacity(0.18))
                                                .stroke(AlongTheme.Colors.accent, lineWidth: 2)
                                        }
                                    }
                                    .mapStyle(.standard(elevation: .flat))
                                    .onMapCameraChange(frequency: .onEnd) { context in
                                        viewModel.updateMapRegion(context.region)
                                    }
                                    .frame(height: 190)
                                    .clipShape(RoundedRectangle(cornerRadius: AlongTheme.Radius.small))
                                    .overlay(alignment: .center) {
                                        Image(systemName: "mappin")
                                            .font(.title2.weight(.semibold))
                                            .foregroundStyle(AlongTheme.Colors.accent)
                                            .shadow(color: .white, radius: 3)
                                            .offset(y: -9)
                                            .allowsHitTesting(false)
                                    }
                                }

                                Text(viewModel.selectedAddress ?? "Move the map to a location, then tap Use map center.")
                                    .font(.alongCaption)
                                    .foregroundStyle(AlongTheme.Colors.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: AlongTheme.Spacing.md) {
                                    Button {
                                        Task { await viewModel.useMapCenter() }
                                    } label: {
                                        Label("Use map center", systemImage: "mappin.and.ellipse")
                                    }
                                    .font(.alongCaption.weight(.semibold))
                                    .foregroundStyle(AlongTheme.Colors.accent)

                                    Button {
                                        Task { await viewModel.useCurrentLocation() }
                                    } label: {
                                        HStack(spacing: AlongTheme.Spacing.xs) {
                                            if viewModel.isGettingLocation { ProgressView() }
                                            Text(viewModel.isGettingLocation ? "Getting…" : "Use my location")
                                        }
                                    }
                                    .font(.alongCaption.weight(.semibold))
                                    .foregroundStyle(AlongTheme.Colors.accent)
                                    .disabled(viewModel.isGettingLocation)
                                }

                                if let lat = viewModel.latitude, let lon = viewModel.longitude {
                                    Text(String(format: "%.5f, %.5f", lat, lon))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                                }
                            }
                        }
                        Text("Drag the map to position the pin. The circle previews the alert radius.")
                            .font(.alongCaption)
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                    }

                    VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
                        Text("Radius: \(AlongFormatters.distance(viewModel.radius))")
                            .font(.alongCaption.weight(.medium))
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                        Slider(value: $viewModel.radius,
                               in: Validators.minPlaceRadius...Validators.maxPlaceRadius,
                               step: 25)
                        .tint(AlongTheme.Colors.accent)
                    }

                    if let error = viewModel.errorMessage {
                        AlongErrorBanner(message: error)
                    }
                    if viewModel.needsPermissionSettings {
                        Button("Open Settings") {
                            viewModel.openPermissionSettings()
                        }
                        .font(.alongCaption.weight(.semibold))
                        .foregroundStyle(AlongTheme.Colors.accent)
                    }

                    Toggle("Monitor this place and alert me", isOn: $viewModel.monitorPlace)
                        .tint(AlongTheme.Colors.accent)
                        .padding(14)
                        .background(AlongTheme.Colors.card, in: RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous))

                    Button {
                        Task {
                            if await viewModel.save() { dismiss() }
                        }
                    } label: {
                        if viewModel.isWorking {
                            ProgressView().tint(AlongTheme.Colors.onAccent).frame(maxWidth: .infinity)
                        } else {
                            Text(viewModel.monitorPlace ? "Save and Enable Alerts" : "Save Place")
                        }
                    }
                    .buttonStyle(.alongPrimary)
                    .disabled(viewModel.isWorking)
                }
                .padding(AlongTheme.Spacing.lg)
            }
            .background(AlongTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
