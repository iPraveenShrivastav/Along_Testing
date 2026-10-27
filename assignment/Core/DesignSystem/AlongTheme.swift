//
//  AlongTheme.swift
//  assignment
//
//  Created by praveen on 27/10/26.
//

import SwiftUI
import UIKit

enum AlongTheme {
    enum Colors {
        static let background = dynamic(light: 0xF9F7F3, dark: 0x191816)
        static let card = dynamic(light: 0xFFFFFF, dark: 0x242220)
        static let cardMuted = dynamic(light: 0xF1EEE8, dark: 0x2C2A27)
        static let primaryText = dynamic(light: 0x2C2A26, dark: 0xF1EFEA)
        static let secondaryText = dynamic(light: 0x6E6960, dark: 0xA8A299)
        static let accent = dynamic(light: 0x6E8B66, dark: 0xA3C19A)
        static let accentSoft = dynamic(light: 0xE7EDE2, dark: 0x31402D)
        static let onAccent = dynamic(light: 0xFFFFFF, dark: 0x1D241B)
        static let separator = dynamic(light: 0xE5E1D9, dark: 0x3B3833)
        static let danger = dynamic(light: 0xB15A50, dark: 0xD68B82)
        static let warning = dynamic(light: 0xB08945, dark: 0xD3AC6B)
        static let stale = dynamic(light: 0x9C968A, dark: 0x8B857A)
        static let mapOverlay = dynamic(light: 0xFFFFFF, dark: 0x242220)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 16
        static let sheet: CGFloat = 20
        static let pill: CGFloat = 999
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Font {
    static let alongTitle = Font.title2.weight(.semibold)
    static let alongHeadline = Font.headline
    static let alongBody = Font.body
    static let alongCaption = Font.caption
}
