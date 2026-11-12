import SwiftUI
import CoreLocation

struct TrackView: View {
    @EnvironmentObject private var store: TrackStore
    @EnvironmentObject private var gps: LocationService

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(label: "Track · works with no signal",
                       title: store.recording == nil ? "Ready" : "Recording",
                       left: headerLeft, right: "")
            if let notice = store.notice {
                Text(notice)
                    .font(Theme.bodySm).foregroundColor(Theme.ink)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.amberBg)
            }
            List {
                Section {
                    statusRows
                    recordButton
                }
                .listRowBackground(Theme.surface200)

                if !store.tracks.isEmpty {
                    Section("Saved tracks") {
                        ForEach(store.tracks.filter { $0.id != store.recording?.id }) { track in
                            TrackRow(track: track)
                                .listRowBackground(Theme.surface200)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button(role: .destructive) { store.delete(track.id) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface100.ignoresSafeArea())
        .overlay(alignment: .bottom) { undoBar }
        .animation(.easeInOut(duration: 0.2), value: store.lastDeleted?.track.id)
        .onAppear { gps.start() }
    }

    private var headerLeft: String {
        guard let r = store.recording else { return "Not recording" }
        return "\(r.points.count) points · \(miles(r.distanceMeters)) mi"
    }

    @ViewBuilder private var statusRows: some View {
        if gps.isDenied {
            VStack(alignment: .leading, spacing: 4) {
                Text("Location is off for Trailbook").font(Theme.heading).foregroundColor(Theme.ink)
                Text("Turn it on in Settings → Privacy & Security → Location Services → Trailbook.")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            .padding(.vertical, 8)
        } else if let loc = gps.location {
            VStack(alignment: .leading, spacing: 6) {
                Text(coordText(loc.coordinate)).font(Theme.coord).foregroundColor(Theme.ink)
                Text("Elevation \(Int((loc.altitude * 3.28084).rounded())) ft · Accuracy ±\(Int((loc.horizontalAccuracy * 3.28084).rounded())) ft")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            .padding(.vertical, 8)
        } else {
            Text("Waiting for a GPS fix. Step outside if you are indoors.")
                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                .padding(.vertical, 8)
        }
    }

    private var recordButton: some View {
        Button {
            if store.recording == nil { store.startRecording() } else { store.stopRecording() }
        } label: {
            Text(store.recording == nil ? "Start recording" : "Stop and save")
                .font(Theme.heading)
                .frame(maxWidth: .infinity, minHeight: Theme.tapMin + 8)
                .foregroundColor(store.recording == nil ? Theme.onForest : .white)
                .background(store.recording == nil ? Theme.forest : Theme.ember)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        }
        .buttonStyle(.plain)
        .disabled(gps.isDenied)
        .accessibilityHint(store.recording == nil ? "Starts saving your path" : "Stops and saves the track")
    }

    @ViewBuilder private var undoBar: some View {
        if let d = store.lastDeleted {
            HStack {
                Text("Deleted “\(d.track.name)”").font(Theme.body).lineLimit(1)
                Spacer()
                Button("Undo") { store.undoDelete() }
                    .font(Theme.heading).frame(minHeight: Theme.tapMin)
            }
            .padding(.horizontal, 16)
            .background(Theme.ink).foregroundColor(Theme.surface100)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func coordText(_ c: CLLocationCoordinate2D) -> String {
        String(format: "%.5f° %@, %.5f° %@",
               abs(c.latitude), c.latitude >= 0 ? "N" : "S",
               abs(c.longitude), c.longitude >= 0 ? "E" : "W")
    }
}

private func miles(_ meters: Double) -> String { String(format: "%.2f", meters / 1609.344) }

private struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name).font(Theme.body).foregroundColor(Theme.ink)
                Text("\(miles(track.distanceMeters)) mi · \(track.points.count) points")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            Spacer()
            ShareLink(item: GPXFile(track: track),
                      preview: SharePreview(track.name)) {
                Label("GPX", systemImage: "square.and.arrow.up")
                    .font(Theme.bodySm.weight(.bold))
                    .frame(minWidth: Theme.tapMin, minHeight: Theme.tapMin)
            }
            .accessibilityLabel("Share \(track.name) as a GPX file")
        }
        .frame(minHeight: Theme.tapMin)
    }
}
