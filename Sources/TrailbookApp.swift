import SwiftUI

@main
struct TrailbookApp: App {
    @StateObject private var prep = PrepStore()
    @StateObject private var tracks = TrackStore()
    @StateObject private var gps = LocationService()
    @StateObject private var weather = WeatherStore()
    @StateObject private var meals = MealStore()
    @StateObject private var trip = TripProgress()
    @StateObject private var trips = TripStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prep)
                .environmentObject(tracks)
                .environmentObject(gps)
                .environmentObject(weather)
                .environmentObject(meals)
                .environmentObject(trip)
                .environmentObject(trips)
                .tint(Theme.forest)
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case trip = "Base Camp", weather = "Weather", prep = "Prep", track = "Track", compass = "Compass", meals = "Meals"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .trip: return "tent"
        case .weather: return "cloud.sun"
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
    @EnvironmentObject private var trip: TripProgress
    @EnvironmentObject private var trips: TripStore
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
        .onAppear {
            MealStore.tripDays = trips.current?.dayLabels ?? MealStore.tripDays
            gps.onLocation = { tracks.add($0); trip.update($0, destination: trips.current?.location) }
            trip.onStart = { gps.start() }
            // A drive that was running when the app closed keeps listening.
            if trip.phase == .driving { gps.start() }
        }
    }

    /// Sets the day labels first, then rebuilds Meals whenever the trip changes.
    private func mealsView() -> some View {
        MealStore.tripDays = trips.current?.dayLabels ?? MealStore.tripDays
        return MealsView().id(trips.current?.id)
    }

    @ViewBuilder private func content(for section: AppSection) -> some View {
        switch section {
        case .trip: TripView()
        case .weather: NavigationStack { WeatherView() }
        case .prep: PrepView()
        case .track: TrackView()
        case .compass: CompassView()
        case .meals: mealsView()
        }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 8) {
            if open {
                ForEach(AppSection.allCases.reversed()) { section in
                    Button {
                        selected = section
                        withAnimation(.easeInOut(duration: 0.2)) { open = false }
                    } label: {
                        Image(systemName: section.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 56, height: 56)
                            .background(section == selected ? Theme.ink : Theme.surface200)
                            .foregroundColor(section == selected ? Theme.surface100 : Theme.ink)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                            .shadow(radius: 3, y: 2)
                    }
                    .accessibilityLabel(section.rawValue)
                    .accessibilityAddTraits(section == selected ? .isSelected : [])
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
            } label: {
                Image(systemName: open ? "xmark" : selected.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 60, height: 60)
                    .background(Theme.ember)
                    .foregroundColor(Color(UIColor(hex: 0x1F2A22)))
                    .clipShape(Circle())
                .shadow(radius: 4, y: 2)
            }
            .accessibilityLabel(open ? "Close menu" : "Menu, \(selected.rawValue)")
        }
        .padding(.leading, 16)
        .padding(.bottom, 8)
    }
}
