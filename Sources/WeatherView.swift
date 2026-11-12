import SwiftUI

/// Full forecast: every day from the National Weather Service, and hour by hour for each day.
struct WeatherView: View {
    /// True when opened from the Trip page, which supplies the back arrow.
    var pushed = false
    @EnvironmentObject private var weather: WeatherStore
    @EnvironmentObject private var trips: TripStore

    private var lat: Double { trips.current?.latitude ?? 37.0842 }
    private var lon: Double { trips.current?.longitude ?? -91.4417 }
    private var tripKeys: Set<String> { Set(trips.current?.dayKeys ?? []) }

    private var updated: String {
        guard let f = weather.fetched else { return "Not loaded yet" }
        return "Updated " + f.formatted(date: .omitted, time: .shortened)
    }

    private var status: String {
        if weather.fetched == nil {
            return weather.failed ? "No forecast yet. No signal." : "Loading the forecast…"
        }
        return weather.failed ? "Showing the saved forecast. No signal." : "Source: National Weather Service"
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Weather · \(trips.current?.rangeLabel ?? "No trip")",
                title: "Forecast",
                left: trips.current?.name ?? "Plan a trip to pick a place",
                right: updated,
                summit: .chimborazo
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
                                    if tripKeys.contains(d.dateKey) {
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
        .task(id: trips.current?.id) {
            if weather.needsRefresh(latitude: lat, longitude: lon) {
                await weather.refresh(latitude: lat, longitude: lon)
            }
        }
        .toolbar(pushed ? .visible : .hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeatherDayView: View {
    let day: ForecastDay
    @EnvironmentObject private var weather: WeatherStore

    private var hours: [ForecastPeriod] { weather.hours(for: day.dateKey) }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Weather · Forecast",
                title: day.weekday,
                left: day.first?.shortForecast ?? "",
                right: "Rain \(day.maxRain)%",
                summit: .chimborazo
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
                if !hours.isEmpty {
                    Section("Hour by hour") {
                        ForEach(hours) { h in
                            HStack(spacing: 8) {
                                Text(h.hourLabel).font(.subheadline.monospacedDigit()).frame(width: 52, alignment: .leading)
                                Text("\(h.temperature)°").font(.headline).frame(width: 44, alignment: .leading)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(h.shortForecast).font(.subheadline).lineLimit(1)
                                    Text("Rain \(h.rainChance)% · \(h.windDirection) \(h.windSpeed)")
                                        .font(.footnote).foregroundStyle(Theme.inkMuted)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 44)
                            .accessibilityElement(children: .combine)
                        }
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
