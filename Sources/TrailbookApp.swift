import SwiftUI

@main
struct TrailbookApp: App {
    @StateObject private var prep = PrepStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(prep)
                .tint(Theme.forest)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            TripView()
                .tabItem { Label("Trip", systemImage: "flag") }
            PrepView()
                .tabItem { Label("Prep", systemImage: "checkmark.square") }
            PlaceholderView(title: "Maps", note: "Offline maps and GPS tracks arrive in stage 2.")
                .tabItem { Label("Maps", systemImage: "map") }
            CompassView()
                .tabItem { Label("Compass", systemImage: "location.north.circle") }
            PlaceholderView(title: "Meals", note: "The meal plan arrives in a later stage.")
                .tabItem { Label("Meals", systemImage: "fork.knife") }
        }
    }
}
