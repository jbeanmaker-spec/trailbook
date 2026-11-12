import SwiftUI

/// The current trip: live forecast for its days, the drive recap, and your trips.
struct TripView: View {
    @EnvironmentObject private var weather: WeatherStore
    @EnvironmentObject private var trip: TripProgress
    @EnvironmentObject private var trips: TripStore
    @State private var planning = false

    private var current: Trip? { trips.current }
    private var lat: Double { current?.latitude ?? 37.0842 }
    private var lon: Double { current?.longitude ?? -91.4417 }

    private var dayTiles: [(name: String, day: ForecastDay?)] {
        guard let t = current else { return [] }
        return Array(t.dayKeys.prefix(4)).map { k in
            let d = weather.days.first { $0.dateKey == k }
            let label = d?.weekday ?? String((t.dayLabels[t.dayKeys.firstIndex(of: k) ?? 0]).prefix(3)).uppercased()
            return (label, d)
        }
    }

    private var status: String {
        guard let f = weather.fetched else {
            return weather.failed ? "NO FORECAST YET · NO SIGNAL" : "LOADING FORECAST"
        }
        let t = f.formatted(date: .omitted, time: .shortened)
        return weather.failed ? "SAVED FORECAST FROM \(t) · NO SIGNAL" : "LIVE · NWS · UPDATED \(t)"
    }

    private var watch: String? {
        for t in dayTiles { if let d = t.day, d.maxRain >= 50 {
            return "Rain likely \(d.weekday): \(d.maxRain)% chance. Trails may be muddy."
        } }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderBand(
                    label: "Base Camp · \(current?.rangeLabel ?? "No trip yet")",
                    title: current?.name ?? "Plan a trip",
                    left: current?.place ?? "Pick a place and dates",
                    right: trip.phase == .arrived ? "Arrived" : "\(current?.nights ?? 0) nights",
                    summit: .cotopaxi
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if current != nil {
                            Text(status)
                                .font(Theme.label).tracking(1)
                                .foregroundColor(weather.failed ? Theme.amber : Theme.inkMuted)
                            NavigationLink {
                                WeatherView(pushed: true)
                            } label: {
                                HStack(spacing: 8) {
                                    ForEach(0..<dayTiles.count, id: \.self) { i in
                                        let t = dayTiles[i]
                                        DayTile(day: t.name,
                                                high: t.day?.day.map { "\($0.temperature)°" } ?? "--",
                                                note: t.day.map { x in
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
                            Text("Tap the forecast for every day, hour by hour.")
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                            DriveRecap()
                        }
                        YourTrips(planning: $planning)
                    }
                    .padding(16)
                }
            }
            .background(Theme.surface100.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: current?.id) {
                if weather.needsRefresh(latitude: lat, longitude: lon) {
                    await weather.refresh(latitude: lat, longitude: lon)
                }
            }
            .sheet(isPresented: $planning) {
                PlanTripView().presentationDetents([.large])
            }
        }
    }
}

private struct YourTrips: View {
    @EnvironmentObject private var trips: TripStore
    @Binding var planning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR TRIPS").font(Theme.label).tracking(1).foregroundColor(Theme.inkMuted)
            ForEach(trips.trips) { t in
                Button { trips.select(t.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: t.id == trips.current?.id ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(t.id == trips.current?.id ? Theme.forest : Theme.inkMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name).font(Theme.heading).foregroundColor(Theme.ink)
                            Text("\(t.rangeLabel) · \(t.place)")
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.tapMin, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { trips.delete(t.id) } label: {
                        Label("Delete trip", systemImage: "trash")
                    }
                }
            }
            if !trips.trips.isEmpty {
                Text("Press and hold a trip to delete it.")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            Button { planning = true } label: {
                Label("Plan a trip", systemImage: "plus")
                    .font(Theme.heading)
                    .frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                    .background(Theme.forest)
                    .foregroundColor(Theme.onForest)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).stroke(Theme.line, lineWidth: 1))
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

