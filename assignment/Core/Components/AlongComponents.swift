//
//  AlongComponents.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI

struct AlongPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.alongHeadline)
            .foregroundStyle(AlongTheme.Colors.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous)
                    .fill(isEnabled ? AlongTheme.Colors.accent : AlongTheme.Colors.stale)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AlongSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.alongHeadline)
            .foregroundStyle(AlongTheme.Colors.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous)
                    .strokeBorder(AlongTheme.Colors.accent, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == AlongPrimaryButtonStyle {
    static var alongPrimary: AlongPrimaryButtonStyle { AlongPrimaryButtonStyle() }
    static var alongSecondary: AlongSecondaryButtonStyle { AlongSecondaryButtonStyle() }
}

struct AlongCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(AlongTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AlongTheme.Radius.card, style: .continuous)
                    .fill(AlongTheme.Colors.card)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
    }
}

struct AlongEmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: AlongTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(AlongTheme.Colors.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(.alongHeadline)
                .foregroundStyle(AlongTheme.Colors.primaryText)
            Text(message)
                .font(.alongBody)
                .foregroundStyle(AlongTheme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.alongSecondary)
                    .frame(maxWidth: 240)
            }
        }
        .padding(AlongTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AlongErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: AlongTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AlongTheme.Colors.danger)
            Text(message)
                .font(.alongCaption)
                .foregroundStyle(AlongTheme.Colors.primaryText)
            Spacer(minLength: 0)
        }
        .padding(AlongTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AlongTheme.Radius.small, style: .continuous)
                .fill(AlongTheme.Colors.danger.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }
}

struct AlongStatusPill: View {
    enum Tone { case active, paused, warning, neutral }

    let text: String
    let tone: Tone
    var systemImage: String?

    private var color: Color {
        switch tone {
        case .active: return AlongTheme.Colors.accent
        case .paused: return AlongTheme.Colors.stale
        case .warning: return AlongTheme.Colors.warning
        case .neutral: return AlongTheme.Colors.secondaryText
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .font(.alongCaption.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(color.opacity(0.14))
        )
        .accessibilityElement(children: .combine)
    }
}

struct AlongAvatar: View {
    let name: String
    var size: CGFloat = 36

    private var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(AlongTheme.Colors.onAccent)
            .frame(width: size, height: size)
            .background(Circle().fill(AlongTheme.Colors.accent))
            .accessibilityLabel(Text("\(name) avatar"))
    }
}

struct AlongFormField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var isNewPassword: Bool = false
    @State private var isRevealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AlongTheme.Spacing.xs) {
            Text(title)
                .font(.alongCaption.weight(.medium))
                .foregroundStyle(AlongTheme.Colors.secondaryText)
            HStack {
                Group {
                    if isSecure && !isRevealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                            .autocorrectionDisabled(keyboardType == .emailAddress)
                    }
                }
                .textContentType(
                    isSecure
                        ? (isNewPassword ? .newPassword : .password)
                        : (keyboardType == .emailAddress ? .emailAddress : nil)
                )
                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(AlongTheme.Colors.secondaryText)
                    }
                    .accessibilityLabel(isRevealed ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AlongTheme.Radius.small, style: .continuous)
                    .fill(AlongTheme.Colors.card)
                    .strokeBorder(AlongTheme.Colors.separator, lineWidth: 1)
            )
        }
    }
}

struct AlongSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.alongCaption.weight(.semibold))
            .foregroundStyle(AlongTheme.Colors.secondaryText)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}
