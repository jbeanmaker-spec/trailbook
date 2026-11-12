import SwiftUI

/// Live National Weather Service forecast. A plain list under the same dark header as the other pages.
struct WeatherView: View {
    /// True when opened from the Trip page, which supplies the back arrow.
    var pushed = false
    @EnvironmentObject private var weather: WeatherStore

    // The sample trip's location (Ozarks). Real trips set this later.
    private let lat = 37.0842
    private let lon = -91.4417

    // Sample trip dates, matching the Trip page.
    private let tripDays: Set<String> = ["2026-11-13", "2026-11-14", "2026-11-15"]

    private var updated: String {
        guard let f = weather.fetched else { return "Not loaded yet" }
        return "Updated " + f.formatted(date: .omitted, time: .shortened)
    }

    private var status: String {
        if weather.fetched == nil {
            return weather.failed ? "No forecast yet. No signal." : "Tap Refresh to load the forecast."
        }
        return weather.failed ? "Showing the saved forecast. No signal." : "Source: National Weather Service"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Weather · Fri Nov 13 → Sun Nov 15",
                title: "Forecast",
                left: weather.place.isEmpty ? "Ozark Highlands" : "Ozark Highlands · \(weather.place)",
                right: updated
            )
            List {
                Section {
                    Text(status).font(.footnote).foregroundStyle(weather.failed ? Theme.amber : Theme.inkMuted)
                    Button(weather.isLoading ? "Refreshing…" : "Refresh forecast") {
                        Task { await weather.refresh(latitude: lat, longitude: lon) }
                    }
                    .disabled(weather.isLoading)
                    .frame(minHeight: Theme.tapMin)
                }
                Section {
                    ForEach(weather.days) { d in
                        NavigationLink {
                            WeatherDayView(day: d)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(d.weekday).font(.headline)
                                    if tripDays.contains(d.dateKey) {
                                        Text("TRIP")
                                            .font(.system(size: 11, weight: .bold)).tracking(1)
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Theme.ember)
                                            .foregroundColor(Color(UIColor(hex: 0x1F2A22)))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Text(d.day.map { "\($0.temperature)°" } ?? "--")
                                        .font(.title3.bold())
                                    Text(d.night.map { "/ \($0.temperature)°" } ?? "")
                                        .foregroundStyle(Theme.inkMuted)
                                }
                                Text("\(d.first?.shortForecast ?? "") · \(d.maxRain)% rain")
                                    .font(.footnote).foregroundStyle(Theme.inkMuted)
                            }
                            .frame(minHeight: Theme.tapMin)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface100.ignoresSafeArea())
        .task {
            // Load when the page opens, unless the saved forecast is under 30 minutes old.
            if let f = weather.fetched, Date().timeIntervalSince(f) < 1800 { return }
            await weather.refresh(latitude: lat, longitude: lon)
        }
        .toolbar(pushed ? .visible : .hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeatherDayView: View {
    let day: ForecastDay
    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Weather · Forecast",
                title: day.weekday,
                left: day.first?.shortForecast ?? "",
                right: "Rain \(day.maxRain)%"
            )
            List {
                ForEach([day.day, day.night].compactMap { $0 }) { p in
                    Section(p.name) {
                        Text("\(p.temperature)°\(p.temperatureUnit) · \(p.shortForecast)").font(.headline)
                        Text("Rain \(p.rainChance)% · Wind \(p.windDirection) \(p.windSpeed)")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)
                        Text(p.detailedForecast)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface100.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
