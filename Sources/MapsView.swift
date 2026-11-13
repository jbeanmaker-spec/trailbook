import SwiftUI
import MapKit

/// The map. Shows the USGS map from the phone when it is saved, from the network otherwise.
struct MapsView: View {
    @EnvironmentObject private var tracks: TrackStore
    @EnvironmentObject private var trips: TripStore
    @EnvironmentObject private var maps: MapStore
    @EnvironmentObject private var layers: MapLayerSettings
    @State private var showOffline = false
    @State private var showLayers = false
    @State private var showGPS = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Maps · works with no signal",
                title: layers.base.title,
                left: trips.current?.place ?? "Missouri",
                right: maps.summary,
                summit: .antisana
            )
            ZStack {
                TopoMapView(
                    center: trips.current?.location.coordinate,
                    base: layers.base,
                    relief: layers.relief,
                    route: (tracks.recording?.points ?? []).map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                    },
                    saved: layers.savedTracks ? savedLines : [],
                    savedKey: layers.savedTracks ? tracks.tracks.filter { $0.id != tracks.recording?.id }.map { "\($0.id)\($0.points.count)" }.joined() : ""
                )
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        GPSChip { showGPS = true }
                        Spacer()
                    }
                    Spacer()
                    if layers.base == .topo {
                        Text("USGS The National Map")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.surface200.opacity(0.85))
                            .foregroundColor(Theme.inkMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(10)
                Button { showLayers = true } label: {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(Theme.surface200.opacity(0.92))
                        .foregroundColor(Theme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1))
                }
                .accessibilityLabel("Map layers")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 64).padding(.trailing, 10)
            }
            Button { showOffline = true } label: {
                Label("Offline maps", systemImage: "arrow.down.circle")
                    .font(Theme.heading)
                    .frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                    .background(Theme.forest)
                    .foregroundColor(Theme.onForest)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                    .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
            }
        }
        .background(Theme.surface100.ignoresSafeArea())
        .sheet(isPresented: $showOffline) { OfflineMapsView().presentationDetents([.large]) }
        .sheet(isPresented: $showLayers) { LayersView().presentationDetents([.medium, .large]) }
        .sheet(isPresented: $showGPS) { GPSSheet().presentationDetents([.large]) }
        .background(GPSBootstrap())
    }

    private var savedLines: [[CLLocationCoordinate2D]] {
        tracks.tracks
            .filter { $0.id != tracks.recording?.id && $0.points.count > 1 }
            .map { t in t.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } }
    }
}

struct TopoMapView: UIViewRepresentable {
    var center: CLLocationCoordinate2D?
    var base: BaseMap
    var relief: Bool
    var route: [CLLocationCoordinate2D]
    var saved: [[CLLocationCoordinate2D]]
    var savedKey: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.delegate = context.coordinator
        v.showsUserLocation = true
        v.showsCompass = true
        v.showsScale = true
        v.pointOfInterestFilter = .excludingAll
        let c = center ?? CLLocationCoordinate2D(latitude: 38.4, longitude: -92.5)
        v.setRegion(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)),
                    animated: false)
        context.coordinator.lastCenter = center

        let track = MKUserTrackingButton(mapView: v)
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        track.layer.cornerRadius = 8
        v.addSubview(track)
        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
            track.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -10),
        ])
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        let co = context.coordinator
        if let c = center,
           co.lastCenter?.latitude != c.latitude || co.lastCenter?.longitude != c.longitude {
            co.lastCenter = c
            v.setRegion(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)),
                        animated: true)
        }

        // Base map, relief and saved tracks: rebuilt only when one of them changes.
        let sig = "\(base.rawValue)|\(relief)|\(savedKey)"
        if co.layerSig != sig {
            co.layerSig = sig
            for o in co.layerOverlays { v.removeOverlay(o) }
            co.layerOverlays = []
            v.mapType = base == .road ? .mutedStandard : .standard
            if let service = base.service {
                let o = CachedTileOverlay(service: service, replacesMap: true)
                co.layerOverlays.append(o)
                v.addOverlay(o, level: .aboveLabels)
                if relief && base == .topo || relief && base == .satellite {
                    let r = CachedTileOverlay(service: "USGSShadedReliefOnly", replacesMap: false, opacity: 0.45)
                    co.layerOverlays.append(r)
                    v.addOverlay(r, level: .aboveLabels)
                }
            }
            for line in saved {
                let p = MKPolyline(coordinates: line, count: line.count)
                p.title = "saved"
                co.layerOverlays.append(p)
                v.addOverlay(p, level: .aboveLabels)
            }
            co.routeCount = -1   // the recording line must be drawn above the rest
        }

        if co.routeCount != route.count {
            co.routeCount = route.count
            if let old = co.line { v.removeOverlay(old) }
            if route.count > 1 {
                let line = MKPolyline(coordinates: route, count: route.count)
                co.line = line
                v.addOverlay(line, level: .aboveLabels)
            } else {
                co.line = nil
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var lastCenter: CLLocationCoordinate2D?
        var routeCount = 0
        var line: MKPolyline?
        var layerSig = ""
        var layerOverlays: [MKOverlay] = []

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? CachedTileOverlay {
                let r = MKTileOverlayRenderer(tileOverlay: tiles)
                r.alpha = tiles.opacity
                return r
            }
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                if line.title == "saved" {
                    r.strokeColor = UIColor(hex: 0x2F6FDB).withAlphaComponent(0.85)
                    r.lineWidth = 3
                } else {
                    r.strokeColor = UIColor(hex: 0xFF5C00)
                    r.lineWidth = 4
                }
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

/// Pick an area, download it on Wi-Fi, use it with no signal.
struct OfflineMapsView: View {
    @EnvironmentObject private var maps: MapStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(maps.summary) on this phone · Wi-Fi recommended")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    if let n = maps.notice {
                        Text(n).font(Theme.bodySm).foregroundColor(Theme.amber)
                    }
                }
                Section("Missouri") {
                    ForEach(MapRegion.all) { region in
                        RegionRow(region: region)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                if maps.records[region.id] != nil {
                                    Button(role: .destructive) { maps.delete(region) } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(Theme.redOrange)
                                }
                            }
                    }
                }
                Section("Credit") {
                    Text("Data available from U.S. Geological Survey, National Geospatial Program. Free to use and in the public domain. Maps can be out of date. Trails and roads change; check land-manager rules before you go.")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
            }
            .navigationTitle("Offline maps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct RegionRow: View {
    @EnvironmentObject private var maps: MapStore
    let region: MapRegion

    private var record: RegionRecord? { maps.records[region.id] }
    private var active: Bool { maps.downloading == region.id }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(region.name).font(Theme.heading).foregroundColor(Theme.ink)
                Text(region.subtitle).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                Text(status).font(Theme.label).foregroundColor(record?.complete == true ? Theme.forest : Theme.inkMuted)
                if let r = record, !r.complete {
                    ProgressView(value: r.fraction)
                }
            }
            Spacer(minLength: 0)
            if record?.complete != true {
                Button(active ? "Pause" : "Download") {
                    if active { maps.pause() } else { maps.start(region) }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: Theme.tapMin)
            }
        }
        .padding(.vertical, 4)
    }

    private var status: String {
        guard let r = record else { return "About \(MapStore.size(region.estimatedBytes))" }
        if r.complete {
            let d = r.updated?.formatted(.dateTime.month(.abbreviated).year()) ?? ""
            return "DOWNLOADED · \(MapStore.size(r.bytes)) · UPDATED \(d.uppercased())"
        }
        let pct = Int(r.fraction * 100)
        return active ? "DOWNLOADING · \(pct)%" : "PAUSED · \(pct)%"
    }
}

/// Applies the saved GPS options and starts the GPS when the Maps page appears.
/// Kept in its own small view so the map itself does not redraw on every GPS fix.
private struct GPSBootstrap: View {
    @EnvironmentObject private var gps: LocationService
    var body: some View {
        Color.clear.onAppear {
            let d = UserDefaults.standard
            gps.setLowPower(d.bool(forKey: "lowPowerTracking"))
            UIApplication.shared.isIdleTimerDisabled = d.bool(forKey: "keepScreenOn")
            gps.start()
        }
    }
}
