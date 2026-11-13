import SwiftUI
import CoreLocation

private func feet(_ m: Double) -> Int { Int((m * 3.28084).rounded()) }

private func compassPoint(_ deg: Double) -> String {
    let names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    return names[Int(((deg + 22.5).truncatingRemainder(dividingBy: 360)) / 45) % 8]
}

private func coordText(_ c: CLLocationCoordinate2D) -> String {
    String(format: "%.4f° %@, %.4f° %@",
           abs(c.latitude), c.latitude >= 0 ? "N" : "S",
           abs(c.longitude), c.longitude >= 0 ? "E" : "W")
}

private func ageText(_ s: TimeInterval) -> String {
    if s < 60 { return "\(Int(s)) s ago" }
    if s < 3600 { return "\(Int(s / 60)) min ago" }
    return "\(Int(s / 3600)) h ago"
}

private func clock(_ s: TimeInterval) -> String {
    let t = Int(max(0, s))
    return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
}

/// Climb in feet, ignoring small GPS bounces.
private func gainFeet(_ t: Track) -> Int {
    var gain = 0.0
    var ref = t.points.first?.ele
    for p in t.points {
        guard let r = ref else { break }
        if p.ele - r >= 3 { gain += p.ele - r; ref = p.ele }
        else if r - p.ele >= 3 { ref = p.ele }
    }
    return feet(gain)
}

/// Small status chip over the map. Tap it for the full GPS page.
struct GPSChip: View {
    @EnvironmentObject private var gps: LocationService
    @EnvironmentObject private var tracks: TrackStore
    var action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
            Button(action: action) {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 9, height: 9)
                    Text(text).font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.surface200.opacity(0.92))
                .foregroundColor(Theme.ink)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Phone GPS \(text). Opens GPS details")
        }
    }

    private var live: Bool {
        guard let l = gps.location else { return false }
        return Date().timeIntervalSince(l.timestamp) < 30 && l.horizontalAccuracy >= 0
    }

    private var color: Color {
        if gps.isDenied { return Theme.danger }
        if tracks.recording != nil { return Theme.ember }
        return live ? Theme.forest : Theme.amber
    }

    private var text: String {
        if gps.isDenied { return "GPS OFF" }
        if let r = tracks.recording {
            return "REC \(String(format: "%.2f", r.distanceMeters / 1609.344)) mi"
        }
        if live, let l = gps.location { return "LOCKED ±\(feet(l.horizontalAccuracy)) ft" }
        return gps.location == nil ? "SEARCHING" : "NO FIX"
    }
}

/// Phone GPS page: fix, position, recording and battery options.
struct GPSSheet: View {
    @EnvironmentObject private var gps: LocationService
    @EnvironmentObject private var tracks: TrackStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepScreenOn") private var keepOn = false
    @AppStorage("lowPowerTracking") private var lowPower = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section { fixBlock }
                if let r = tracks.recording {
                    Section("Recording") { recordingStats(r) }
                }
                Section {
                    Toggle(isOn: $keepOn) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep screen on").font(Theme.body)
                            Text("Stops the screen from locking while Trailbook is open.")
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        }
                    }
                    Toggle(isOn: $lowPower) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Low-power tracking").font(Theme.body)
                            Text("Checks position less often. Saves battery, draws a rougher path.")
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        }
                    }
                }
                Section { recordButton.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }
                Section {
                    Text("Works with no signal. Download offline maps before you leave.")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
            }
            .navigationTitle("Phone GPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onChange(of: keepOn) { _, on in UIApplication.shared.isIdleTimerDisabled = on }
            .onChange(of: lowPower) { _, on in gps.setLowPower(on) }
            .onAppear { gps.start() }
        }
    }

    @ViewBuilder private var fixBlock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if gps.isDenied {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOCATION IS OFF").font(Theme.label).foregroundColor(Theme.danger)
                    Text("Turn it on in Settings → Privacy & Security → Location Services → Trailbook.")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
            } else if let l = gps.location {
                let age = Date().timeIntervalSince(l.timestamp)
                if age < 30 && l.horizontalAccuracy >= 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LOCKED · ±\(feet(l.horizontalAccuracy)) ft")
                            .font(Theme.label).foregroundColor(Theme.forest)
                        Text(coordText(l.coordinate)).font(Theme.coord).foregroundColor(Theme.ink)
                        Text("Fix \(ageText(age))").font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        HStack {
                            stat("ALTITUDE", "\(feet(l.altitude)) ft")
                            stat("HEADING", l.course >= 0 ? "\(Int(l.course))° \(compassPoint(l.course))" : "--")
                            stat("SPEED", l.speed >= 0 ? String(format: "%.1f mph", l.speed * 2.23694) : "--")
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NO FIX · NOT LIVE").font(Theme.label).foregroundColor(Theme.amber)
                        Text("Move to open sky and keep the phone still. Your track is kept, and recording picks up when a fix returns.")
                            .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        Text("Last fix \(ageText(age))").font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        Text(coordText(l.coordinate)).font(Theme.coord).foregroundColor(Theme.ink)
                        Button(copied ? "Copied" : "Copy last position") {
                            UIPasteboard.general.string = coordText(l.coordinate)
                            copied = true
                        }
                        .buttonStyle(.bordered)
                        .frame(minHeight: Theme.tapMin)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEARCHING FOR GPS").font(Theme.label).foregroundColor(Theme.amber)
                    Text("No position yet. Step outside if you are indoors.")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.inkMuted)
            Text(value).font(Theme.coord).foregroundColor(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recordingStats(_ r: Track) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            HStack {
                stat("DISTANCE", String(format: "%.2f mi", r.distanceMeters / 1609.344))
                stat("TIME", clock(ctx.date.timeIntervalSince(r.start)))
                stat("GAIN", "+\(gainFeet(r)) ft")
            }
        }
    }

    private var recordButton: some View {
        Button {
            if tracks.recording == nil { tracks.startRecording() } else { tracks.stopRecording() }
        } label: {
            Text(tracks.recording == nil ? "Start recording" : "Stop and save")
                .font(Theme.heading)
                .frame(maxWidth: .infinity, minHeight: Theme.tapMin + 8)
                .foregroundColor(tracks.recording == nil ? Theme.onForest : .white)
                .background(tracks.recording == nil ? Theme.forest : Theme.ember)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        }
        .buttonStyle(.plain)
        .disabled(gps.isDenied)
    }
}
