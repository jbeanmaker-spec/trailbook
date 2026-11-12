import Combine
import SwiftUI
import CoreLocation

/// Reads the phone's magnetometer. Works with no signal and no map data.
final class CompassModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double?          // degrees, 0 = magnetic north
    @Published var needsCalibration = false
    @Published var unavailable = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1
        unavailable = !CLLocationManager.headingAvailable()
    }

    func start() {
        guard CLLocationManager.headingAvailable() else { unavailable = true; return }
        manager.startUpdatingHeading()
    }

    func stop() { manager.stopUpdatingHeading() }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else {
            needsCalibration = true
            return
        }
        heading = newHeading.magneticHeading
        needsCalibration = newHeading.headingAccuracy > 25
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}

struct CompassView: View {
    @StateObject private var model = CompassModel()

    private static let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                                "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]

    private var headingText: String {
        guard let h = model.heading else { return "—" }
        let index = Int((h / 22.5).rounded()) % 16
        return "\(Self.names[index]) \(Int(h.rounded()) % 360)°"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(label: "Compass · works with no signal", title: headingText,
                       left: "Magnetic north", right: "", summit: .illinizaSur)
            Spacer(minLength: 12)
            Dial(heading: model.heading ?? 0)
                .frame(width: 300, height: 300)
                .opacity(model.heading == nil ? 0.4 : 1)
                .accessibilityElement()
                .accessibilityLabel("Compass")
                .accessibilityValue(headingText)
            Spacer(minLength: 12)
            Group {
                if model.unavailable {
                    Text("This phone has no compass sensor.")
                } else if model.needsCalibration {
                    Text("Calibrate: wave the phone in a figure 8.")
                } else if model.heading == nil {
                    Text("Waiting for the compass…")
                } else {
                    Text("Calibrated. If the dial drifts, wave the phone in a figure 8.")
                }
            }
            .font(Theme.bodySm)
            .foregroundColor(Theme.inkMuted)
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.surface100.ignoresSafeArea())
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

private struct Dial: View {
    let heading: Double

    var body: some View {
        ZStack {
            Circle().fill(Theme.surface200)
            Circle().stroke(Theme.ink, lineWidth: 3)
            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    Rectangle()
                        .fill(Theme.inkMuted)
                        .frame(width: i % 6 == 0 ? 3 : 1.5, height: i % 6 == 0 ? 16 : 8)
                        .offset(y: -142)
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { i, letter in
                    Text(letter)
                        .font(Theme.title)
                        .foregroundColor(letter == "N" ? Theme.ember : Theme.ink)
                        .offset(y: -108)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
            }
            .rotationEffect(.degrees(-heading))
            .animation(.easeOut(duration: 0.15), value: heading)
            // Fixed marker: the direction the top of the phone points.
            Triangle()
                .fill(Theme.forest)
                .frame(width: 22, height: 22)
                .offset(y: -160)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
