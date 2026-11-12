import SwiftUI

/// Live National Weather Service forecast. A plain list, so it stays fast and reliable.
struct WeatherView: View {
    @EnvironmentObject private var weather: WeatherStore

    // The sample trip's location (Ozarks). Real trips set this later.
    private let lat = 37.0842
    private let lon = -91.4417

    private var status: String {
        guard let f = weather.fetched else {
            return weather.failed ? "No forecast yet. No signal." : "Tap Refresh to load the forecast."
        }
        let t = f.formatted(date: .omitted, time: .shortened)
        return weather.failed ? "Saved forecast from \(t). No signal." : "National Weather Service · updated \(t)"
    }

    var body: some View {
        List {
                Section {
                    Text(status).font(.footnote).foregroundStyle(weather.failed ? Theme.amber : Theme.inkMuted)
                    Button(weather.isLoading ? "Refreshing…" : "Refresh forecast") {
                        Task { await weather.refresh(latitude: lat, longitude: lon) }
                    }
                    .disabled(weather.isLoading)
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
            .navigationTitle(weather.place.isEmpty ? "Weather" : weather.place)
    }
}

private struct WeatherDayView: View {
    let day: ForecastDay
    var body: some View {
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
        .navigationTitle(day.weekday)
    }
}
