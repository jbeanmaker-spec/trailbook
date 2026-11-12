import SwiftUI

/// Live National Weather Service forecast. A plain list under the same dark header as the other pages.
struct WeatherView: View {
    /// True when opened from the Trip page, which supplies the back arrow.
    var pushed = false
    @EnvironmentObject private var weather: WeatherStore

    // The sample trip's location (Ozarks). Real trips set this later.
    private let lat = 37.0842
    private let lon = -91.4417

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
                label: "Weather · Missouri",
                title: "Forecast",
                left: weather.place.isEmpty ? "Ozark Highlands" : weather.place,
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
