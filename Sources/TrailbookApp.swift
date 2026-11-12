import SwiftUI

@main
struct TrailbookApp: App {
    @StateObject private var prep = PrepStore()
    @StateObject private var tracks = TrackStore()
    @StateObject private var gps = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prep)
                .environmentObject(tracks)
                .environmentObject(gps)
                .tint(Theme.forest)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var tracks: TrackStore
    @EnvironmentObject private var gps: LocationService

    var body: some View {
        TabView {
            TripView()
                .tabItem { Label("Trip", systemImage: "flag") }
            PrepView()
                .tabItem { Label("Prep", systemImage: "checkmark.square") }
            TrackView()
                .tabItem { Label("Track", systemImage: "figure.hiking") }
            CompassView()
                .tabItem { Label("Compass", systemImage: "location.north.circle") }
            CheckinView()
                .tabItem { Label("Check in", systemImage: "message") }
            PlaceholderView(title: "Meals", note: "The meal plan arrives in a later stage.")
                .tabItem { Label("Meals", systemImage: "fork.knife") }
        }
        .onAppear { gps.onLocation = { tracks.add($0) } }
    }
}
