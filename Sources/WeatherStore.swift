import Foundation
import Combine

// National Weather Service forecast (US only, free, no key).

struct ForecastPeriod: Codable, Identifiable, Equatable, Sendable {
    struct Value: Codable, Equatable, Sendable { let value: Double? }
    let number: Int
    let name: String
    let startTime: String
    let isDaytime: Bool
    let temperature: Int
    let temperatureUnit: String
    let probabilityOfPrecipitation: Value?
    let windSpeed: String
    let windDirection: String
    let shortForecast: String
    let detailedForecast: String
    var id: Int { number }
    var dateKey: String { String(startTime.prefix(10)) }
    var rainChance: Int { Int(probabilityOfPrecipitation?.value ?? 0) }
}

struct ForecastDay: Identifiable {
    let dateKey: String
    let day: ForecastPeriod?
    let night: ForecastPeriod?
    var id: String { dateKey }
    var first: ForecastPeriod? { day ?? night }
    let weekday: String
    private static let parse: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let name: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE"; return f
    }()
    init(dateKey: String, day: ForecastPeriod?, night: ForecastPeriod?) {
        self.dateKey = dateKey; self.day = day; self.night = night
        if let d = Self.parse.date(from: dateKey) { weekday = Self.name.string(from: d).uppercased() }
        else { weekday = dateKey }
    }
    var maxRain: Int { max(day?.rainChance ?? 0, night?.rainChance ?? 0) }
}

private struct PointsResponse: Decodable, Sendable {
    struct Props: Decodable {
        struct Rel: Decodable { struct P: Decodable { let city: String; let state: String }; let properties: P }
        let forecast: String
        let forecastHourly: String?
        let relativeLocation: Rel?
    }
    let properties: Props
}
private struct ForecastResponse: Decodable, Sendable {
    struct Props: Decodable { let periods: [ForecastPeriod] }
    let properties: Props
}
private struct Cache: Codable {
    var periods: [ForecastPeriod]
    var hourly: [ForecastPeriod]? = nil
    var fetched: Date
    var place: String
    var latitude: Double? = nil
    var longitude: Double? = nil
}

@MainActor
final class WeatherStore: ObservableObject {
    @Published private(set) var periods: [ForecastPeriod] = [] { didSet { days = Self.group(periods) } }
    @Published private(set) var days: [ForecastDay] = []
    @Published private(set) var hourly: [ForecastPeriod] = []
    @Published private(set) var fetched: Date?
    @Published private(set) var place = ""
    private var lat: Double?
    private var lon: Double?
    @Published private(set) var isLoading = false
    @Published private(set) var failed = false   // true when the last refresh failed

    private let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("weather.json")
    }()

    init() {
        if let data = try? Data(contentsOf: url),
           let c = try? JSONDecoder().decode(Cache.self, from: data) {
            periods = c.periods; days = Self.group(c.periods); fetched = c.fetched; place = c.place
            hourly = c.hourly ?? []; lat = c.latitude; lon = c.longitude
        }
    }

    private static func group(_ periods: [ForecastPeriod]) -> [ForecastDay] {
        var order: [String] = []
        var groups: [String: [ForecastPeriod]] = [:]
        for p in periods {
            if groups[p.dateKey] == nil { order.append(p.dateKey) }
            groups[p.dateKey, default: []].append(p)
        }
        return order.map { k in
            let g = groups[k] ?? []
            return ForecastDay(dateKey: k, day: g.first { $0.isDaytime }, night: g.first { !$0.isDaytime })
        }
    }

    /// True when there is no forecast for this place, or it is over 30 minutes old.
    func needsRefresh(latitude: Double, longitude: Double) -> Bool {
        guard let f = fetched, let la = lat, let lo = lon else { return true }
        if abs(la - latitude) > 0.05 || abs(lo - longitude) > 0.05 { return true }
        return Date().timeIntervalSince(f) > 1800
    }

    /// Hour-by-hour periods for one day (date key like 2026-11-14).
    func hours(for dateKey: String) -> [ForecastPeriod] {
        hourly.filter { $0.dateKey == dateKey }
    }

    /// Old data stays on screen if the network fails.
    func refresh(latitude: Double, longitude: Double) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let pts: PointsResponse = try await get(
                "https://api.weather.gov/points/\(String(format: "%.4f", latitude)),\(String(format: "%.4f", longitude))")
            guard let fURL = URL(string: pts.properties.forecast) else { throw URLError(.badURL) }
            let fc: ForecastResponse = try await get(fURL.absoluteString)
            periods = fc.properties.periods
            if let hURL = pts.properties.forecastHourly {
                // The hourly forecast is a bonus. If it fails, the daily forecast still shows.
                if let h: ForecastResponse = try? await get(hURL) { hourly = h.properties.periods }
            }
            lat = latitude; lon = longitude
            fetched = Date()
            if let r = pts.properties.relativeLocation?.properties { place = "\(r.city), \(r.state)" }
            failed = false
            let data = try JSONEncoder().encode(Cache(periods: periods, hourly: hourly, fetched: fetched!, place: place, latitude: latitude, longitude: longitude))
            try data.write(to: url, options: .atomic)
        } catch {
            failed = true
        }
    }

    nonisolated private func get<T: Decodable & Sendable>(_ s: String) async throws -> T {
        guard let u = URL(string: s) else { throw URLError(.badURL) }
        var req = URLRequest(url: u, timeoutInterval: 15)
        req.setValue("Trailbook/1.0 (personal camping app)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension ForecastPeriod {
    /// "3 PM" from a start time like 2026-11-14T15:00:00-06:00.
    var hourLabel: String {
        let chars = Array(startTime)
        guard chars.count >= 13, let h = Int(String(chars[11..<13])) else { return "" }
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12) \(h < 12 ? "AM" : "PM")"
    }
}
