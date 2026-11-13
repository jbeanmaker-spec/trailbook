import SwiftUI
import Combine

/// What the map shows. Remembered between launches.
enum BaseMap: String, CaseIterable, Identifiable {
    case topo, satellite, relief, road
    var id: String { rawValue }

    var title: String {
        switch self {
        case .topo: return "Topo"
        case .satellite: return "Satellite"
        case .relief: return "Shaded relief"
        case .road: return "Road"
        }
    }

    var note: String {
        switch self {
        case .topo: return "USGS topo map. Works with no signal in downloaded areas."
        case .satellite: return "USGS aerial photos with roads and names. Needs signal."
        case .relief: return "Hills and valleys shown by shadow. Needs signal."
        case .road: return "Apple road map. Needs signal."
        }
    }

    var icon: String {
        switch self {
        case .topo: return "map"
        case .satellite: return "globe.americas"
        case .relief: return "mountain.2"
        case .road: return "car"
        }
    }

    /// USGS service name, or nil for the Apple road map.
    var service: String? {
        switch self {
        case .topo: return "USGSTopo"
        case .satellite: return "USGSImageryTopo"
        case .relief: return "USGSShadedReliefOnly"
        case .road: return nil
        }
    }
}

final class MapLayerSettings: ObservableObject {
    @Published var base: BaseMap { didSet { UserDefaults.standard.set(base.rawValue, forKey: "map.base") } }
    @Published var relief: Bool { didSet { UserDefaults.standard.set(relief, forKey: "map.relief") } }
    @Published var savedTracks: Bool { didSet { UserDefaults.standard.set(savedTracks, forKey: "map.savedTracks") } }

    init() {
        let d = UserDefaults.standard
        base = BaseMap(rawValue: d.string(forKey: "map.base") ?? "") ?? .topo
        relief = d.bool(forKey: "map.relief")
        savedTracks = d.object(forKey: "map.savedTracks") as? Bool ?? true
    }
}

/// Map layers: pick the base map and turn extras on or off.
struct LayersView: View {
    @EnvironmentObject private var layers: MapLayerSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Base map") {
                    ForEach(BaseMap.allCases) { b in
                        Button { layers.base = b } label: {
                            HStack(spacing: 12) {
                                Image(systemName: b.icon).frame(width: 28)
                                    .foregroundColor(Theme.forest)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.title).font(Theme.heading).foregroundColor(Theme.ink)
                                    Text(b.note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                                }
                                Spacer(minLength: 0)
                                if layers.base == b {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.forest)
                                }
                            }
                            .frame(minHeight: Theme.tapMin)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("Show on map") {
                    Toggle(isOn: $layers.relief) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shaded relief").font(Theme.body)
                            Text("Adds hill shadow on top. Needs signal.")
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        }
                    }
                    .disabled(layers.base == .relief || layers.base == .road)
                    Toggle(isOn: $layers.savedTracks) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("My tracks").font(Theme.body)
                            Text("Draws your saved tracks as blue lines.")
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        }
                    }
                }
                Section {
                    Text("Contour lines, water, trails and roads are part of the Topo map, so they come with it. Only Topo can be saved to the phone for use with no signal.")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
            }
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
