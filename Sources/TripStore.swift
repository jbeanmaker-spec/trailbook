import Combine
import CoreLocation
import Foundation

struct Trip: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var place: String
    var latitude: Double
    var longitude: Double
    var start: Date
    var end: Date
    var people: Int = 2

    private static let keyFormat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let labelFormat: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "EEE MMM d"; return f
    }()

    private var days: [Date] {
        let cal = Calendar.current
        var out: [Date] = []
        var d = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: max(start, end))
        while d <= last && out.count < 21 {
            out.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    var dayKeys: [String] { days.map { Self.keyFormat.string(from: $0) } }
    var dayLabels: [String] { days.map { Self.labelFormat.string(from: $0) } }
    var nights: Int { max(0, days.count - 1) }
    var rangeLabel: String {
        guard let a = dayLabels.first, let b = dayLabels.last else { return "" }
        return a == b ? a : "\(a) → \(b)"
    }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

private struct SavedTrips: Codable {
    var trips: [Trip]
    var currentID: UUID?
}

/// Your trips. The selected one drives the Trip page, forecast, drive recap, meals and pack list.
@MainActor
final class TripStore: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var currentID: UUID?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("Trailbook", isDirectory: true)
                .appendingPathComponent("trips.json")
        }
        load()
    }

    var current: Trip? { trips.first { $0.id == currentID } ?? trips.first }

    func add(_ trip: Trip) {
        trips.append(trip)
        currentID = trip.id
        save()
    }

    func update(_ trip: Trip) {
        guard let i = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[i] = trip
        save()
    }

    func select(_ id: UUID) {
        guard trips.contains(where: { $0.id == id }) else { return }
        currentID = id
        save()
    }

    func delete(_ id: UUID) {
        trips.removeAll { $0.id == id }
        if currentID == id { currentID = trips.first?.id }
        save()
    }

    // MARK: Saving and loading

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let s = try? JSONDecoder().decode(SavedTrips.self, from: data) {
            trips = s.trips
            currentID = s.currentID
            return
        }
        trips = [Self.sampleTrip()]
        currentID = trips.first?.id
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedTrips(trips: trips, currentID: currentID))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // The trip still works on screen. It just will not survive a closed app.
        }
    }

    private static func sampleTrip() -> Trip {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 13)) ?? Date()
        let end = cal.date(from: DateComponents(year: 2026, month: 11, day: 15)) ?? Date()
        return Trip(name: "Ozark Highlands", place: "Ozark Highlands, MO",
                    latitude: 37.0842, longitude: -91.4417, start: start, end: end)
    }
}

/// Starting points for "Plan a trip". Coordinates are approximate.
struct Spot: Identifiable {
    let name: String
    let latitude: Double
    let longitude: Double
    var id: String { name }

    static let missouri: [Spot] = [
        Spot(name: "Ozark Highlands", latitude: 37.0842, longitude: -91.4417),
        Spot(name: "Johnson's Shut-Ins State Park", latitude: 37.5336, longitude: -90.8483),
        Spot(name: "Elephant Rocks State Park", latitude: 37.6406, longitude: -90.6269),
        Spot(name: "Meramec State Park", latitude: 38.2141, longitude: -91.1001),
        Spot(name: "Lake of the Ozarks State Park", latitude: 38.1297, longitude: -92.6017),
        Spot(name: "Cuivre River State Park", latitude: 39.0258, longitude: -90.9340),
        Spot(name: "Big Spring, Current River", latitude: 36.9467, longitude: -90.9847),
    ]
}
