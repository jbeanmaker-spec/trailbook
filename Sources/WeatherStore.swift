import Foundation
import Combine

// National Weather Service forecast (US only, free, no key).

struct ForecastPeriod: Codable, Identifiable, Equatable {
    struct Value: Codable, Equatable { let value: Double? }
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

private struct PointsResponse: Decodable {
    struct Props: Decodable {
        struct Rel: Decodable { struct P: Decodable { let city: String; let state: String }; let properties: P }
        let forecast: String
        let relativeLocation: Rel?
    }
    let properties: Props
}
private struct ForecastResponse: Decodable {
    struct Props: Decodable { let periods: [ForecastPeriod] }
    let properties: Props
}
private struct Cache: Codable {
    var periods: [ForecastPeriod]
    var fetched: Date
    var place: String
}

@MainActor
final class WeatherStore: ObservableObject {
    @Published private(set) var periods: [ForecastPeriod] = [] { didSet { days = Self.group(periods) } }
    @Published private(set) var days: [ForecastDay] = []
    @Published private(set) var fetched: Date?
    @Published private(set) var place = ""
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
            fetched = Date()
            if let r = pts.properties.relativeLocation?.properties { place = "\(r.city), \(r.state)" }
            failed = false
            let data = try JSONEncoder().encode(Cache(periods: periods, fetched: fetched!, place: place))
            try data.write(to: url, options: .atomic)
        } catch {
            failed = true
        }
    }

    private func get<T: Decodable>(_ s: String) async throws -> T {
        guard let u = URL(string: s) else { throw URLError(.badURL) }
        var req = URLRequest(url: u, timeoutInterval: 15)
        req.setValue("Trailbook/1.0 (personal camping app)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
