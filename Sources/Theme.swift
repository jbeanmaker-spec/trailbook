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
    static let redOrange = Color(light: 0xE8450F, dark: 0xFF7043)
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
    var summit: Summit = .cotopaxi
    @State private var showSummit = false

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
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                Color(UIColor(hex: 0x1F2A22))
                TopoLines(summit: summit)
            }
        )
        .overlay(alignment: .bottomTrailing) {
            Text(summit.caption)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(1)
                .foregroundColor(Color(UIColor(hex: 0x9BD3A6)).opacity(0.85))
                .padding(.trailing, 16)
                .padding(.bottom, 6)
                .opacity(showSummit ? 1 : 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.2)) { showSummit = true }
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 0.6)) { showSummit = false }
            }
        }
        .clipped()
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

/// The ten tallest summits of Ecuador, one per page header (stylized contours, not survey data).
enum Summit: CaseIterable {
    case cotopaxi, chimborazo, cayambe, antisana, elAltar
    case illinizaSur, sangay, tungurahua, carihuairazo, cotacachi

    var name: String {
        switch self {
        case .cotopaxi: return "Cotopaxi"
        case .chimborazo: return "Chimborazo"
        case .cayambe: return "Cayambe"
        case .antisana: return "Antisana"
        case .elAltar: return "El Altar"
        case .illinizaSur: return "Illiniza Sur"
        case .sangay: return "Sangay"
        case .tungurahua: return "Tungurahua"
        case .carihuairazo: return "Carihuairazo"
        case .cotacachi: return "Cotacachi"
        }
    }

    var meters: Double {
        switch self {
        case .cotopaxi: return 5897
        case .chimborazo: return 6263
        case .cayambe: return 5790
        case .antisana: return 5753
        case .elAltar: return 5319
        case .illinizaSur: return 5248
        case .sangay: return 5230
        case .tungurahua: return 5023
        case .carihuairazo: return 5018
        case .cotacachi: return 4944
        }
    }

    var caption: String {
        let feet = Int((meters * 3.28084).rounded())
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return "\(name.uppercased()) · \(f.string(from: NSNumber(value: feet)) ?? "\(feet)") ft"
    }

    fileprivate var raw: String {
        switch self {
        case .cotopaxi: return SummitData.cotopaxiLines
        case .chimborazo: return SummitData.chimborazoLines
        case .cayambe: return SummitData.cayambeLines
        case .antisana: return SummitData.antisanaLines
        case .elAltar: return SummitData.elAltarLines
        case .illinizaSur: return SummitData.illinizaSurLines
        case .sangay: return SummitData.sangayLines
        case .tungurahua: return SummitData.tungurahuaLines
        case .carihuairazo: return SummitData.carihuairazoLines
        case .cotacachi: return SummitData.cotacachiLines
        }
    }

    /// Parsed once per summit and kept, so scrolling and redraws stay cheap.
    private static var cache: [Int: [ContourLine]] = [:]
    var lines: [ContourLine] {
        let key = Summit.allCases.firstIndex(of: self) ?? 0
        if let hit = Summit.cache[key] { return hit }
        let parsed = ContourLine.parse(raw)
        Summit.cache[key] = parsed
        return parsed
    }
}

struct ContourLine {
    let opacity: Double
    let width: Double
    let points: [CGPoint]

    static func parse(_ text: String) -> [ContourLine] {
        var out: [ContourLine] = []
        for row in text.split(separator: "\n") {
            let halves = row.split(separator: "|", maxSplits: 1)
            guard halves.count == 2 else { continue }
            let head = halves[0].split(separator: " ")
            guard head.count == 2, let o = Double(head[0]), let w = Double(head[1]) else { continue }
            var pts: [CGPoint] = []
            for pair in halves[1].split(separator: " ") {
                let xy = pair.split(separator: ",")
                if xy.count == 2, let x = Double(xy[0]), let y = Double(xy[1]) {
                    pts.append(CGPoint(x: x, y: y))
                }
            }
            if pts.count > 1 { out.append(ContourLine(opacity: o, width: w, points: pts)) }
        }
        return out
    }
}

/// Light green, single-tone contour lines of one summit, drawn behind a page header.
/// The 390 x 200 drawing is scaled to cover the band and pinned to the upper right,
/// so the summit stays in view. Decoration only: hidden from VoiceOver, never takes taps.
struct TopoLines: View {
    var summit: Summit = .cotopaxi
    private let green = Color(UIColor(hex: 0x9BD3A6))

    var body: some View {
        let lines = summit.lines
        Canvas { ctx, size in
            let scale = max(size.width / 390, size.height / 200)
            let dx = size.width - 390 * scale
            for line in lines {
                var path = Path()
                for (i, p) in line.points.enumerated() {
                    let pt = CGPoint(x: dx + p.x * scale, y: p.y * scale)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                ctx.stroke(path, with: .color(green.opacity(line.opacity)),
                           style: StrokeStyle(lineWidth: line.width, lineCap: .round, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
