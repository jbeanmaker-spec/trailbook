import Combine
import CoreLocation
import Foundation

enum TripPhase: String, Codable { case ready, driving, arrived }

private struct SavedTrip: Codable {
    var phase: TripPhase
    var departed: Date?
    var arrivedAt: Date?
    var distanceMeters: Double
}

/// Tracks the drive to the trip's destination: departure, drive time, distance and arrival.
/// Saved to the phone, so a closed app picks up where it left off.
@MainActor
final class TripProgress: ObservableObject {
    /// The sample trip's destination (Ozark Highlands). Real trips set this later.
    static let destination = CLLocation(latitude: 37.0842, longitude: -91.4417)
    static let arrivalRadius: CLLocationDistance = 200

    @Published private(set) var phase: TripPhase = .ready
    @Published private(set) var departed: Date?
    @Published private(set) var arrivedAt: Date?
    /// Rounded to 0.1 mile so the screen only redraws when it matters.
    @Published private(set) var milesDriven: Double = 0
    @Published private(set) var milesToGo: Double?

    /// Set by the app: turns on the phone GPS when a drive starts.
    var onStart: (() -> Void)?

    private var meters: Double = 0
    private var last: CLLocation?
    private var updates = 0
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("Trailbook", isDirectory: true)
                .appendingPathComponent("trip.json")
        }
        if let data = try? Data(contentsOf: self.fileURL),
           let s = try? JSONDecoder().decode(SavedTrip.self, from: data) {
            phase = s.phase; departed = s.departed; arrivedAt = s.arrivedAt
            meters = s.distanceMeters
            milesDriven = Self.miles(s.distanceMeters)
        }
    }

    // MARK: Actions

    func start() {
        phase = .driving
        departed = Date()
        arrivedAt = nil
        meters = 0; milesDriven = 0; milesToGo = nil
        last = nil
        save()
        onStart?()
    }

    func markArrived() {
        guard phase == .driving else { return }
        phase = .arrived
        arrivedAt = Date()
        save()
    }

    func reset() {
        phase = .ready
        departed = nil; arrivedAt = nil
        meters = 0; milesDriven = 0; milesToGo = nil
        last = nil
        save()
    }

    /// Called for every GPS fix.
    func update(_ loc: CLLocation, destination dest: CLLocation? = nil) {
        let destination = dest ?? Self.destination
        guard phase == .driving, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 100 else { return }
        if let prev = last {
            let step = loc.distance(from: prev)
            // Ignore GPS jitter (under 5 m) and impossible jumps (over 2 km between fixes).
            if step >= 5 && step < 2000 { meters += step }
        }
        last = loc
        let driven = Self.miles(meters)
        if driven != milesDriven { milesDriven = driven }
        let toGo = Self.miles(loc.distance(from: destination))
        if toGo != milesToGo { milesToGo = toGo }
        updates += 1
        if loc.distance(from: destination) <= Self.arrivalRadius {
            markArrived()
        } else if updates % 20 == 0 {
            save()
        }
    }

    // MARK: Helpers

    private static func miles(_ meters: Double) -> Double {
        (meters / 1609.344 * 10).rounded() / 10
    }

    private func save() {
        let s = SavedTrip(phase: phase, departed: departed, arrivedAt: arrivedAt, distanceMeters: meters)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(s).write(to: fileURL, options: .atomic)
        } catch {
            // The drive still works. It just will not survive a closed app.
        }
    }
}
