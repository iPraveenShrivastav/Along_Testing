//
//  MapsView.swift
//  assignment
//
//  Created by praveen on 28/10/26.
//

import SwiftUI
import MapKit

struct MapsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: MapsViewModel?
    @State private var showGroups = false
    @State private var showProfile = false
    @State private var showSavedPlaces = false
    @State private var sheetPosition: GroupSheetPosition = .compact
    @State private var mapStyleSelection: AlongMapStyle = .standard

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    mapLayer

                    if let viewModel {
                        floatingControls(viewModel, geometry: geometry)
                        GroupOverviewSheet(
                            appState: appState,
                            viewModel: viewModel,
                            position: $sheetPosition,
                            openGroups: { showGroups = true },
                            openSavedPlaces: { showSavedPlaces = true }
                        )
                        .frame(height: sheetPosition.height(in: geometry.size.height, bottomInset: geometry.safeAreaInsets.bottom))
                        .frame(maxWidth: .infinity)
                    } else {
                        ProgressView()
                            .padding(20)
                            .background(.regularMaterial, in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AlongTheme.Colors.background)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showGroups) { GroupsSheet() }
            .sheet(isPresented: $showProfile) { ProfileSheet() }
            .sheet(isPresented: $showSavedPlaces) { SavedPlacesSheet() }
            .onAppear {
                if viewModel == nil { viewModel = MapsViewModel(appState: appState) }
                appState.reconcileGeofences()
            }
            .onChange(of: appState.session?.places) { _, _ in appState.reconcileGeofences() }
            .onChange(of: appState.session?.placesLoaded) { _, loaded in
                if loaded == true { appState.reconcileGeofences() }
            }
            .onChange(of: appState.locationService.authorizationStatus) { _, _ in
                appState.reconcileGeofences()
            }
        }
    }


    @ViewBuilder
    private var mapLayer: some View {
        if let viewModel {
            Map(position: Binding(
                get: { viewModel.cameraPosition },
                set: { viewModel.cameraPosition = $0 }
            )) {
                UserAnnotation()
                ForEach(viewModel.sharingMembers, id: \.member.id) { entry in
                    Annotation(entry.member.displayName, coordinate: entry.location.coordinate) {
                        MemberAnnotationView(
                            member: entry.member,
                            location: entry.location,
                            isSelected: viewModel.selectedMemberID == entry.member.id
                        )
                        .onTapGesture { viewModel.selectedMemberID = entry.member.id }
                    }
                }
                ForEach(viewModel.savedPlaces) { place in
                    MapCircle(center: place.coordinate, radius: place.radius)
                        .foregroundStyle(place.enabled
                                         ? AlongTheme.Colors.accent.opacity(0.16)
                                         : Color.gray.opacity(0.08))
                        .stroke(place.enabled
                                ? AlongTheme.Colors.accent.opacity(0.8)
                                : Color.gray.opacity(0.55), lineWidth: 2)
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        SavedPlaceMapAnnotation(
                            name: place.name,
                            status: viewModel.placeMapStatus(for: place),
                            isEnabled: place.enabled
                        )
                    }
                }
            }
            .mapStyle(mapStyleSelection.mapKitStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()
        } else {
            AlongTheme.Colors.background.ignoresSafeArea()
        }
    }


    @ViewBuilder
    private func floatingControls(_ viewModel: MapsViewModel, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                FloatingMapButton(systemImage: "mappin.and.ellipse", label: "Add safe place") {
                    showSavedPlaces = true
                }

                Button { showGroups = true } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AlongTheme.Colors.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.selectedGroup?.name ?? "Choose a group")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AlongTheme.Colors.primaryText)
                                .lineLimit(1)
                            Text(groupSubtitle)
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                                .foregroundStyle(AlongTheme.Colors.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 50)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.32), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Select group, \(appState.selectedGroup?.name ?? "no group selected")")
                .accessibilityHint("Opens your groups")

                Button { showProfile = true } label: {
                    AlongAvatar(name: appState.user?.displayName ?? "?", size: 34)
                        .padding(8)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile and settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

                HStack {
                    if let error = viewModel.actionError ?? appState.startupError {
                        AlongErrorBanner(message: error)
                            .onTapGesture { viewModel.actionError = nil }
                            .padding(.top, 10)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(AlongMapStyle.allCases) { style in
                            Button {
                                mapStyleSelection = style
                            } label: {
                                if mapStyleSelection == style {
                                    Label(style.title, systemImage: "checkmark")
                                } else {
                                    Text(style.title)
                                }
                            }
                        }
                    } label: {
                        FloatingControlFace(systemImage: "square.3.layers.3d", label: "Map style")
                    }
                    .accessibilityLabel("Map style")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                permissionNotice

            Spacer(minLength: 0)

            if let detail = viewModel.selectedMemberDetail {
                MemberDetailCard(member: detail.member, location: detail.location) {
                    viewModel.selectedMemberID = nil
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            HStack {
                Button {
                    Task { await viewModel.toggleSharing() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: appState.isSharingInSelectedGroup ? "location.fill" : "location.slash")
                            .font(.system(size: 14, weight: .semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sharing")
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                            Text(appState.isSharingInSelectedGroup ? "On" : "Off")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        }
                    }
                    .foregroundStyle(appState.isSharingInSelectedGroup ? AlongTheme.Colors.accent : AlongTheme.Colors.stale)
                    .frame(minWidth: 104, minHeight: 50, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(
                        (appState.isSharingInSelectedGroup ? AlongTheme.Colors.accent : AlongTheme.Colors.stale).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedGroupID == nil || viewModel.isTogglingSharing)
                .accessibilityLabel(appState.isSharingInSelectedGroup ? "Pause location sharing" : "Enable location sharing")
                .accessibilityHint("Toggles location sharing for the selected group")

                Spacer(minLength: 0)
                Button { viewModel.recenter() } label: {
                    FloatingControlFace(systemImage: "location.north.fill", label: "Recenter map")
                }
                .disabled(viewModel.isLocating)
                .accessibilityLabel("Center map on my location")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.bottom, GroupSheetPosition.compact.height(
            in: geometry.size.height,
            bottomInset: geometry.safeAreaInsets.bottom
        ) + 14)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: sheetPosition)
    }

    @ViewBuilder
    private var permissionNotice: some View {
        let status = appState.locationService.authorizationStatus
        if status == .denied || status == .restricted {
            HStack(spacing: 10) {
                Image(systemName: "location.slash.fill")
                    .foregroundStyle(AlongTheme.Colors.warning)
                Text("Location access is off")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(AlongTheme.Colors.primaryText)
                Spacer(minLength: 2)
                Button("Settings") { appState.locationService.openSystemSettings() }
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(AlongTheme.Colors.accent)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
    }

    private var groupSubtitle: String {
        guard let group = appState.selectedGroup else {
            return appState.groups.isEmpty ? "Create or join a group" : "Tap to switch groups"
        }
        let count = group.memberIds.count
        return "\(count) member\(count == 1 ? "" : "s")"
    }
}

private enum AlongMapStyle: String, CaseIterable, Identifiable {
    case standard
    case satellite
    case hybrid

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var mapKitStyle: MapStyle {
        switch self {
        case .standard: return .standard(elevation: .realistic)
        case .satellite: return .imagery(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        }
    }
}

private struct FloatingMapButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FloatingControlFace(systemImage: systemImage, label: label)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct FloatingControlFace: View {
    let systemImage: String
    let label: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AlongTheme.Colors.primaryText)
            .frame(width: 46, height: 46)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.32), lineWidth: 1))
            .shadow(color: .black.opacity(0.13), radius: 12, y: 4)
            .contentShape(Circle())
            .accessibilityLabel(label)
    }
}

private enum GroupSheetPosition: Equatable {
    case compact
    case medium
    case expanded

    func height(in availableHeight: CGFloat, bottomInset: CGFloat) -> CGFloat {
        let usable = max(availableHeight, 1)
        switch self {
        case .compact: return min(usable * 0.16, 132) + bottomInset
        case .medium: return min(usable * 0.51, 430) + bottomInset
        case .expanded: return max(usable - 12, 1) + bottomInset
        }
    }

    func next(translation: CGFloat) -> GroupSheetPosition {
        switch (self, translation) {
        case (.compact, ..<(-35)): return .medium
        case (.medium, ..<(-35)): return .expanded
        case (.medium, 36...): return .compact
        case (.expanded, 36...): return .medium
        default: return self
        }
    }
}

private struct GroupOverviewSheet: View {
    let appState: AppState
    let viewModel: MapsViewModel
    @Binding var position: GroupSheetPosition
    let openGroups: () -> Void
    let openSavedPlaces: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0

    private var members: [GroupMember] { appState.session?.members ?? [] }
    private var sortedMembers: [GroupMember] { members.sorted(by: memberOrder) }
    private var activePlaces: [SavedPlace] { (appState.session?.places ?? []).filter(\.enabled) }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            sheetHeader

            if position != .compact {
                Rectangle()
                    .fill(AlongTheme.Colors.separator.opacity(0.65))
                    .frame(height: 1)
                    .padding(.top, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        membersSection
                        placesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 26,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 26,
                style: .continuous
            )
            .fill(.regularMaterial)
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 26,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 26,
                    style: .continuous
                )
                .strokeBorder(AlongTheme.Colors.separator.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 22, y: -5)
            .ignoresSafeArea(edges: position == .expanded ? .all : .bottom)
        }
        .offset(y: max(0, dragTranslation))
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: position)
    }

    private var dragHandle: some View {
        Capsule()
            .fill(AlongTheme.Colors.secondaryText.opacity(0.38))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 25)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragTranslation) { value, state, _ in state = max(0, value.translation.height) }
                    .onEnded { value in position = position.next(translation: value.translation.height) }
            )
            .onTapGesture {
                switch position {
                case .compact: position = .medium
                case .medium: position = .expanded
                case .expanded: position = .medium
                }
            }
            .accessibilityLabel("Expand or collapse group panel")
            .accessibilityAddTraits(.isButton)
    }

    private var sheetHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.selectedGroup?.name ?? "Your group")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AlongTheme.Colors.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(groupSummary)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                    if appState.isSharingInSelectedGroup {
                        Text("·")
                        Label("Sharing", systemImage: "location.fill")
                            .font(.system(.caption, design: .rounded).weight(.medium))
                    }
                }
                .foregroundStyle(AlongTheme.Colors.secondaryText)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: openGroups) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AlongTheme.Colors.accent)
                    .frame(width: 40, height: 40)
                    .background(AlongTheme.Colors.accent.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change group")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 2)
    }

    private var groupSummary: String {
        guard let group = appState.selectedGroup else {
            return appState.groups.isEmpty ? "Create or join a group" : "Choose a group to view members"
        }
        let count = group.memberIds.count
        return "\(count) member\(count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("People")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AlongTheme.Colors.primaryText)
                Spacer()
                if let inviteText = invitationText {
                    ShareLink(item: inviteText) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AlongTheme.Colors.accent)
                            .frame(width: 38, height: 38)
                            .background(AlongTheme.Colors.accent.opacity(0.12), in: Circle())
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Invite people by sharing the group ID")
                    .accessibilityHint("People must request to join and be approved")
                }
            }

            if appState.selectedGroup == nil {
                EmptyOverviewCard(
                    image: "person.3",
                    title: appState.groups.isEmpty ? "Start your group" : "Choose a group",
                    message: appState.groups.isEmpty
                        ? "Create a group or request to join one to see everyone here."
                        : "Select a group to see its members and places.",
                    actionTitle: appState.groups.isEmpty ? "Create or join a group" : "Select group",
                    action: openGroups
                )
            } else if appState.session?.error != nil {
                EmptyOverviewCard(
                    image: "wifi.exclamationmark",
                    title: "Can’t load this group",
                    message: appState.session?.error ?? "Check your connection and try again.",
                    actionTitle: "Open groups",
                    action: openGroups
                )
            } else if members.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading group members…")
                        .font(.subheadline)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AlongTheme.Colors.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedMembers) { member in
                        GroupMemberMapRow(
                            member: member,
                            location: member.id.flatMap { appState.session?.location(uid: $0) },
                            isCurrentUser: member.id == appState.uid
                        )
                        if member.id != sortedMembers.last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }
                .padding(.horizontal, 13)
                .background(AlongTheme.Colors.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func memberOrder(_ lhs: GroupMember, _ rhs: GroupMember) -> Bool {
        if lhs.id == appState.uid { return true }
        if rhs.id == appState.uid { return false }
        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private var invitationText: String? {
        guard let group = appState.selectedGroup, let groupID = group.id else { return nil }
        return "Join my Along group \(group.name). Open Along and request to join using this group ID: \(groupID)"
    }

    @ViewBuilder
    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Saved places")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AlongTheme.Colors.primaryText)
            }

            if appState.selectedGroupID == nil {
                Text("Choose a group to view its saved places.")
                    .font(.subheadline)
                    .foregroundStyle(AlongTheme.Colors.secondaryText)
            } else if appState.session?.placesLoaded == false {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("Loading saved places…")
                        .font(.subheadline)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                }
                .padding(.vertical, 4)
            } else if activePlaces.isEmpty {
                EmptyOverviewCard(
                    image: "mappin.and.ellipse",
                    title: "No saved places yet",
                    message: "Add a place to see its alert area on the map.",
                    actionTitle: "Add a place",
                    action: openSavedPlaces
                )
            } else {
                VStack(spacing: 9) {
                    ForEach(activePlaces.prefix(3)) { place in
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 21))
                                .foregroundStyle(AlongTheme.Colors.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AlongTheme.Colors.primaryText)
                                    .lineLimit(1)
                                Text(viewModel.placeMapStatus(for: place))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(AlongTheme.Colors.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(AlongFormatters.distance(place.radius))
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(AlongTheme.Colors.secondaryText)
                        }
                        .padding(11)
                        .background(AlongTheme.Colors.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                }
            }
        }
    }

}

private struct GroupMemberMapRow: View {
    let member: GroupMember
    let location: SharedLocation?
    let isCurrentUser: Bool

    private var status: String {
        guard member.sharingEnabled else { return "Location sharing is off" }
        guard let location else { return "Waiting for location" }
        guard let updatedAt = location.updatedAt else { return "Location time unavailable" }
        return "\(location.staleness.label) · \(AlongFormatters.relativeTimestamp(updatedAt))"
    }

    private var statusColor: Color {
        guard member.sharingEnabled else { return AlongTheme.Colors.stale }
        guard let location else { return AlongTheme.Colors.warning }
        return location.staleness.isStale ? AlongTheme.Colors.warning : AlongTheme.Colors.accent
    }

    var body: some View {
        HStack(spacing: 11) {
            AlongAvatar(name: member.displayName, size: 39)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(AlongTheme.Colors.card, lineWidth: 2))
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AlongTheme.Colors.primaryText)
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("You")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(AlongTheme.Colors.accent)
                    }
                }
                Text(status)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AlongTheme.Colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(member.sharingEnabled ? "Sharing" : "Paused")
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
        .frame(minHeight: 62)
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyOverviewCard: View {
    let image: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: image)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AlongTheme.Colors.primaryText)
            Text(message)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(AlongTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(AlongTheme.Colors.accent)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(AlongTheme.Colors.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

private struct SavedPlaceMapAnnotation: View {
    let name: String
    let status: String
    let isEnabled: Bool

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(isEnabled ? AlongTheme.Colors.accent : AlongTheme.Colors.secondaryText)
                Text(name)
                    .foregroundStyle(AlongTheme.Colors.primaryText)
                    .lineLimit(1)
            }
            .font(.system(size: 12, weight: .semibold))
            Text(status)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(status.hasPrefix("At ") || status.hasPrefix("Outside ")
                                 ? AlongTheme.Colors.accent
                                 : AlongTheme.Colors.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isEnabled ? AlongTheme.Colors.accent.opacity(0.3) : Color.gray.opacity(0.25), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MemberAnnotationView: View {
    let member: GroupMember
    let location: SharedLocation
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            AlongAvatar(name: member.displayName, size: 34)
                .overlay {
                    Circle().stroke(isSelected ? AlongTheme.Colors.accent : Color.clear, lineWidth: 3)
                }
                .opacity(location.staleness.isStale ? 0.55 : 1)
            if location.staleness.isStale {
                Text(location.staleness.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AlongTheme.Colors.stale)
            }
        }
        .accessibilityLabel("\(member.displayName), \(location.staleness.label) location")
    }
}

struct MemberDetailCard: View {
    let member: GroupMember
    let location: SharedLocation
    let onClose: () -> Void

    var body: some View {
        AlongCard {
            HStack(spacing: AlongTheme.Spacing.md) {
                AlongAvatar(name: member.displayName, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.alongHeadline)
                        .foregroundStyle(AlongTheme.Colors.primaryText)
                    HStack(spacing: 6) {
                        AlongStatusPill(
                            text: location.staleness.label,
                            tone: location.staleness.isStale ? .neutral : .active
                        )
                        if let updated = location.updatedAt {
                            Text(AlongFormatters.relativeTimestamp(updated))
                                .font(.alongCaption)
                                .foregroundStyle(AlongTheme.Colors.secondaryText)
                        }
                    }
                    Text("Accuracy \(AlongFormatters.accuracy(location.horizontalAccuracy))")
                        .font(.alongCaption)
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AlongTheme.Colors.secondaryText)
                }
                .accessibilityLabel("Close member details")
            }
        }
    }
}
