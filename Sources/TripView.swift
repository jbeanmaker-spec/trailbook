import SwiftUI

/// Sample trip header with a live National Weather Service forecast. Trip planning arrives later.
struct TripView: View {
    @EnvironmentObject private var weather: WeatherStore
    @EnvironmentObject private var gps: LocationService
    @State private var selectedKey: String?

    // Wentzville, MO until the phone has a fix.
    private var lat: Double { gps.location?.coordinate.latitude ?? 38.8114 }
    private var lon: Double { gps.location?.coordinate.longitude ?? -90.8529 }

    private var status: String {
        guard let f = weather.fetched else {
            return weather.failed ? "NO FORECAST YET · NO SIGNAL" : "LOADING FORECAST"
        }
        let t = f.formatted(date: .omitted, time: .shortened)
        return weather.failed ? "SAVED FORECAST FROM \(t) · NO SIGNAL" : "NWS FORECAST · UPDATED \(t)"
    }

    private var watch: String? {
        let wet = weather.days.prefix(3).filter { $0.maxRain >= 50 }
        guard let d = wet.first else { return nil }
        return "Rain likely \(d.weekday): \(d.maxRain)% chance. Trails may be muddy."
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Fri Nov 13 → Sun Nov 15 · Missouri",
                title: "Ozark Highlands",
                left: weather.place.isEmpty ? "Forecast" : weather.place,
                right: "Sample trip"
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(status)
                        .font(Theme.label).tracking(1)
                        .foregroundColor(weather.failed ? Theme.amber : Theme.inkMuted)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(weather.days.prefix(7)) { d in
                                Button { selectedKey = d.dateKey } label: {
                                    DayTile(day: d.weekday,
                                            high: d.day.map { "\($0.temperature)°" } ?? "--",
                                            note: d.night.map { "Low \($0.temperature)° · \(d.maxRain)% rain" } ?? "\(d.maxRain)% rain",
                                            selected: d.dateKey == (selectedKey ?? weather.days.first?.dateKey))
                                }
                                .buttonStyle(.plain)
                                .frame(width: 140)
                            }
                        }
                    }
                    if let d = weather.days.first(where: { $0.dateKey == (selectedKey ?? weather.days.first?.dateKey) }) {
                        DayDetail(day: d)
                    }
                    if let w = watch {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle").foregroundColor(Theme.amber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WATCH").font(Theme.label).tracking(1).foregroundColor(Theme.amber)
                                Text(w).font(Theme.bodySm).foregroundColor(Theme.ink)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amberBg)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                    }
                    Button {
                        Task { await weather.refresh(latitude: lat, longitude: lon) }
                    } label: {
                        Text(weather.isLoading ? "Refreshing…" : "Refresh forecast")
                            .frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                    }
                    .buttonStyle(.bordered)
                    .disabled(weather.isLoading)
                }
                .padding(16)
            }
        }
        .background(Theme.surface100.ignoresSafeArea())
        .task { await weather.refresh(latitude: lat, longitude: lon) }
    }
}

private struct DayDetail: View {
    let day: ForecastDay
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach([day.day, day.night].compactMap { $0 }) { p in
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name.uppercased()).font(Theme.label).tracking(1).foregroundColor(Theme.inkMuted)
                    Text("\(p.temperature)°\(p.temperatureUnit)").font(Theme.display).foregroundColor(Theme.ink)
                    Text(p.shortForecast).font(Theme.heading).foregroundColor(Theme.ink)
                    Text("Rain \(p.rainChance)% · Wind \(p.windDirection) \(p.windSpeed)")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    Text(p.detailedForecast).font(Theme.body).foregroundColor(Theme.ink)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface200)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
            }
        }
    }
}

private struct DayTile: View {
    let day: String
    let high: String
    let note: String
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day).font(Theme.label).tracking(1).foregroundColor(Theme.inkMuted)
            Text(high).font(.system(size: 44, weight: .bold)).foregroundColor(Theme.ink)
                .minimumScaleFactor(0.7)
            Text(note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLg)
                .stroke(selected ? Theme.ink : Theme.line, lineWidth: selected ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
    }
}
