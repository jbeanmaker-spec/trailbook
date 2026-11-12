import SwiftUI

/// Sample trip header with the live National Weather Service forecast for the trip days.
/// Trip planning arrives later.
struct TripView: View {
    @EnvironmentObject private var weather: WeatherStore
    @EnvironmentObject private var trip: TripProgress

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
                    label: "Trip · Fri Nov 13 → Sun Nov 15",
                    title: "Ozark Highlands",
                    left: "37.0842° N, 91.4417° W",
                    right: trip.phase == .arrived ? "Arrived" : "1,402 ft"
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
                        DriveRecap()
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

private struct DriveRecap: View {
    @EnvironmentObject private var trip: TripProgress

    private func time(_ d: Date?) -> String {
        d?.formatted(date: .omitted, time: .shortened) ?? "--"
    }

    private func duration(from: Date?, to: Date) -> String {
        guard let from else { return "--" }
        let mins = max(0, Int(to.timeIntervalSince(from) / 60))
        return mins >= 60 ? "\(mins / 60) h \(mins % 60) min" : "\(mins) min"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.body).foregroundColor(Theme.inkMuted)
            Spacer()
            Text(value).font(Theme.heading).foregroundColor(Theme.ink)
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Theme.label).tracking(1)
                .foregroundColor(trip.phase == .arrived ? Theme.forest : Theme.inkMuted)
            switch trip.phase {
            case .ready:
                Text("Start the drive when you leave. The app times it, counts the miles and tells you when you arrive.")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                action("Start drive", systemImage: "car.fill", prominent: true) { trip.start() }
            case .driving:
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    row("Drive time", duration(from: trip.departed, to: ctx.date))
                }
                row("Departed", time(trip.departed))
                row("Driven", String(format: "%.1f mi", trip.milesDriven))
                row("To go (straight line)", trip.milesToGo.map { String(format: "%.1f mi", $0) } ?? "Waiting for GPS")
                action("I've arrived", systemImage: "checkmark.circle", prominent: true) { trip.markArrived() }
                action("Cancel drive", systemImage: "xmark", prominent: false) { trip.reset() }
            case .arrived:
                Text("Arrived at \(time(trip.arrivedAt))")
                    .font(.system(size: 26, weight: .heavy)).foregroundColor(Theme.forest)
                row("Total drive time", duration(from: trip.departed, to: trip.arrivedAt ?? Date()))
                row("Departed", time(trip.departed))
                row("Distance driven", String(format: "%.1f mi", trip.milesDriven))
                action("Reset", systemImage: "arrow.counterclockwise", prominent: false) { trip.reset() }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.line, lineWidth: 1))
    }

    private var title: String {
        switch trip.phase {
        case .ready: return "DRIVE RECAP"
        case .driving: return "DRIVING"
        case .arrived: return "ARRIVED"
        }
    }

    @ViewBuilder private func action(_ text: String, systemImage: String, prominent: Bool,
                                     _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(text, systemImage: systemImage)
                .font(Theme.heading)
                .frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                .background(prominent ? Theme.ember : Color.clear)
                .foregroundColor(prominent ? Color(UIColor(hex: 0x1F2A22)) : Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd)
                    .stroke(prominent ? Color.clear : Theme.inkMuted, lineWidth: 1))
        }
    }
}
