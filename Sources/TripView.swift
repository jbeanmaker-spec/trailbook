import SwiftUI

/// Sample trip header with the live National Weather Service forecast for the trip days.
/// Trip planning arrives later.
struct TripView: View {
    @EnvironmentObject private var weather: WeatherStore

    // The sample trip: dates and place match the header.
    private let tripKeys = ["2026-11-13", "2026-11-14", "2026-11-15"]
    private let tripNames = ["FRI", "SAT", "SUN"]
    private let lat = 37.0842
    private let lon = -91.4417

    private var tripDays: [ForecastDay?] {
        tripKeys.map { k in weather.days.first { $0.dateKey == k } }
    }

    private var status: String {
        guard let f = weather.fetched else {
            return weather.failed ? "NO FORECAST YET · NO SIGNAL" : "LOADING FORECAST"
        }
        let t = f.formatted(date: .omitted, time: .shortened)
        return weather.failed ? "SAVED FORECAST FROM \(t) · NO SIGNAL" : "LIVE · NWS · UPDATED \(t)"
    }

    private var watch: String? {
        for d in tripDays.compactMap({ $0 }) where d.maxRain >= 50 {
            return "Rain likely \(d.weekday): \(d.maxRain)% chance. Trails may be muddy."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderBand(
                    label: "Missouri · Fri Nov 13 → Sun Nov 15",
                    title: "Ozark Highlands",
                    left: "37.0842° N, 91.4417° W",
                    right: "1,402 ft"
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(status)
                            .font(Theme.label).tracking(1)
                            .foregroundColor(weather.failed ? Theme.amber : Theme.inkMuted)
                        NavigationLink {
                            WeatherView(pushed: true)
                        } label: {
                            HStack(spacing: 12) {
                                ForEach(0..<3, id: \.self) { i in
                                    let d = tripDays[i]
                                    DayTile(day: tripNames[i],
                                            high: d?.day.map { "\($0.temperature)°" } ?? "--",
                                            note: d.map { x in
                                                x.night.map { "Low \($0.temperature)° · \(x.maxRain)%" } ?? "\(x.maxRain)% rain"
                                            } ?? "No data")
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
                        Text("Tap the forecast for every day.")
                            .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    }
                    .padding(16)
                }
            }
            .background(Theme.surface100.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if let f = weather.fetched, Date().timeIntervalSince(f) < 1800 { return }
                await weather.refresh(latitude: lat, longitude: lon)
            }
        }
    }
}

private struct DayTile: View {
    let day: String
    let high: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day).font(Theme.label).tracking(1).foregroundColor(Theme.inkMuted)
            Text(high)
                .font(.system(size: 34, weight: .bold)).foregroundColor(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                .lineLimit(2).minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(Theme.surface200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
