import SwiftUI
import UIKit

/// Colours copied from the Trailbook design tokens (day and night).
enum Theme {
    static let surface100 = Color(light: 0xF4EFE4, dark: 0x121813)
    static let surface200 = Color(light: 0xFFFDF8, dark: 0x1B231C)
    static let surface300 = Color(light: 0xE3DCCB, dark: 0x2A332B)
    static let line = Color(light: 0xC9BFA7, dark: 0x3A463C)
    static let ink = Color(light: 0x1F2A22, dark: 0xEEF0E6)
    static let inkMuted = Color(light: 0x57614F, dark: 0xA8B19F)
    static let forest = Color(light: 0x367761, dark: 0x86C493)
    static let onForest = Color(light: 0xFFFFFF, dark: 0x0F1A12)
    static let ember = Color(light: 0xFF5C00, dark: 0xF08A4B)
    static let sky = Color(light: 0x697A95, dark: 0x86BDE6)
    static let amber = Color(light: 0x8A5A00, dark: 0xF2BE55)
    static let amberBg = Color(light: 0xFFF4DC, dark: 0x2A2312)
    static let danger = Color(light: 0xFF0D00, dark: 0xFF8F85)

    /// Minimum touch target from the design system.
    static let tapMin: CGFloat = 48
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 20

    // Archivo and JetBrains Mono are not bundled yet; these system fonts stand in.
    static let display = Font.system(size: 40, weight: .heavy)
    static let title = Font.system(size: 24, weight: .bold)
    static let heading = Font.system(size: 18, weight: .bold)
    static let body = Font.system(size: 16)
    static let bodySm = Font.system(size: 14)
    static let label = Font.system(size: 12, weight: .bold)
    static let coord = Font.system(size: 14, weight: .medium, design: .monospaced)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// The dark band at the top of each screen: small orange label, big title, one line of detail.
struct HeaderBand: View {
    let label: String
    let title: String
    var left: String = ""
    var right: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(Theme.label).tracking(1)
                .foregroundColor(Theme.ember)
            Text(title)
                .font(Theme.display)
                .foregroundColor(Color(UIColor(hex: 0xF4EFE4)))
            HStack {
                Text(left).font(Theme.coord)
                Spacer()
                Text(right).font(Theme.coord).opacity(0.7)
            }
            .foregroundColor(Color(UIColor(hex: 0xF4EFE4)))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor(hex: 0x1F2A22)))
        .accessibilityElement(children: .combine)
    }
}

struct PlaceholderView: View {
    let title: String
    let note: String

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(label: "Coming later", title: title)
            Text(note)
                .font(Theme.body)
                .foregroundColor(Theme.inkMuted)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .background(Theme.surface100.ignoresSafeArea())
    }
}
