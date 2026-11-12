import SwiftUI

@main
struct TrailbookApp: App {
    @StateObject private var prep = PrepStore()
    @StateObject private var tracks = TrackStore()
    @StateObject private var gps = LocationService()
    @StateObject private var weather = WeatherStore()
    @StateObject private var meals = MealStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prep)
                .environmentObject(tracks)
                .environmentObject(gps)
                .environmentObject(weather)
                .environmentObject(meals)
                .tint(Theme.forest)
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case trip = "Trip", prep = "Prep", track = "Track", compass = "Compass", meals = "Meals"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .trip: return "flag"
        case .prep: return "checkmark.square"
        case .track: return "figure.hiking"
        case .compass: return "location.north.circle"
        case .meals: return "fork.knife"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var tracks: TrackStore
    @EnvironmentObject private var gps: LocationService
    @State private var selected: AppSection = .trip
    @State private var open = false

    var body: some View {
        ZStack {
            // Every section stays alive so scroll position and open pages are kept.
            ForEach(AppSection.allCases) { section in
                content(for: section)
                    .opacity(selected == section ? 1 : 0)
                    .allowsHitTesting(selected == section && !open)
                    .accessibilityHidden(selected != section)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 64) }
        .overlay(alignment: .bottomLeading) { menu }
        .onAppear { gps.onLocation = { tracks.add($0) } }
    }

    @ViewBuilder private func content(for section: AppSection) -> some View {
        switch section {
        case .trip: TripView()
        case .prep: PrepView()
        case .track: TrackView()
        case .compass: CompassView()
        case .meals: MealsView()
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 8) {
            if open {
                VStack(spacing: 0) {
                    ForEach(AppSection.allCases.reversed()) { section in
                        Button {
                            selected = section
                            withAnimation(.easeInOut(duration: 0.2)) { open = false }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: section.icon).frame(width: 28)
                                Text(section.rawValue).font(Theme.heading)
                                Spacer(minLength: 16)
                                if section == selected { Image(systemName: "checkmark") }
                            }
                            .padding(.horizontal, 16)
                            .frame(minWidth: 180, minHeight: Theme.tapMin, alignment: .leading)
                            .foregroundColor(section == selected ? Theme.forest : Theme.ink)
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(section == selected ? .isSelected : [])
                    }
                }
                .background(Theme.surface200)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.line, lineWidth: 1))
                .shadow(radius: 8, y: 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: open ? "chevron.down" : selected.icon)
                    Text(selected.rawValue).font(Theme.heading)
                    if !open { Image(systemName: "chevron.up").font(.footnote.weight(.bold)) }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Theme.forest)
                .foregroundColor(Theme.onForest)
                .clipShape(Capsule())
                .shadow(radius: 4, y: 2)
            }
            .accessibilityLabel(open ? "Close menu" : "Menu, \(selected.rawValue)")
        }
        .padding(.leading, 16)
        .padding(.bottom, 8)
    }
}
