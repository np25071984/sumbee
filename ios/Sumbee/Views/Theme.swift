import SwiftUI

/// The palette from the mockups: pale blue ground, navy ink, one sunny accent. Same values as Android.
enum Palette {
    static let ground = Color(hex: 0xF3F7FC)
    static let ink = Color(hex: 0x1B2A4A)
    static let muted = Color(hex: 0x4A5875)
    static let line = Color(hex: 0xC9D6EA)
    static let track = Color(hex: 0xDCE6F3)
    static let soft = Color(hex: 0xE6EEF8)
    static let softShadow = Color(hex: 0xCBD7E8)
    static let keyShadow = Color(hex: 0xD3DEED)
    static let inkShadow = Color(hex: 0x0B1426)
    static let sun = Color(hex: 0xFFC93C)
    static let sunShadow = Color(hex: 0xD9A21C)
    static let placeholder = Color(hex: 0xA7B4C8)
    static let nudgeBg = Color(hex: 0xFFEBC7)
    static let nudgeInk = Color(hex: 0x8A4B00)
    static let nudgeBorder = Color(hex: 0xF0A93B)
    static let goodBg = Color(hex: 0xDDF3EC)
    static let goodInk = Color(hex: 0x0B6E58)
    static let goodBorder = Color(hex: 0x1E9C7E)
    static let white = Color.white
}

/// Baloo 2 for numbers and headings, Nunito for everything else: both variable fonts, bundled.
enum Fonts {
    static func baloo(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .custom("Baloo 2", fixedSize: size).weight(weight)
    }

    static func nunito(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .custom("Nunito", fixedSize: size).weight(weight)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
