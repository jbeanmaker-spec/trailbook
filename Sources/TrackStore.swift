import Combine
import Foundation
import CoreLocation

/// Records tracks and keeps them safe. The file is saved every few points, so a crash or a dead
/// battery loses at most the last few seconds.
@MainActor
final class TrackStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var recording: Track?
    @Published private(set) var lastDeleted: (track: Track, index: Int)?
    @Published private(set) var notice: String?

    static let minMovement = 5.0       // meters between saved points
    static let maxAccuracy = 50.0      // ignore fixes worse than this, meters
    static let saveEvery = 10          // points

    private let fileURL: URL
    private var undoTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? TrackStore.defaultFileURL()
        load()
    }

    // MARK: Recording

    func startRecording(name: String? = nil) {
        guard recording == nil else { return }
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, h:mm a"
        let title = (name?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 } ?? "Track \(fmt.string(from: now))"
        let track = Track(name: title, start: now)
        recording = track
        tracks.insert(track, at: 0)
        save()
    }

    func add(_ location: CLLocation) {
        guard var track = recording else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= TrackStore.maxAccuracy else { return }
        if let last = track.points.last {
            let prev = CLLocation(latitude: last.lat, longitude: last.lon)
            if location.distance(from: prev) < TrackStore.minMovement { return }
        }
        track.points.append(TrackPoint(lat: location.coordinate.latitude,
                                       lon: location.coordinate.longitude,
                                       ele: location.altitude,
                                       time: location.timestamp,
                                       acc: location.horizontalAccuracy))
        recording = track
        replaceStored(track)
        if track.points.count % TrackStore.saveEvery == 0 { save() }
    }

    func stopRecording() {
        guard var track = recording else { return }
        track.end = Date()
        recording = nil
        replaceStored(track)
        save()
    }

    // MARK: Deleting, with undo

    func delete(_ id: UUID) {
        guard recording?.id != id, let i = tracks.firstIndex(where: { $0.id == id }) else { return }
        lastDeleted = (tracks[i], i)
        tracks.remove(at: i)
        save()
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if !Task.isCancelled { self?.lastDeleted = nil }
        }
    }

    func undoDelete() {
        guard let d = lastDeleted else { return }
        tracks.insert(d.track, at: min(d.index, tracks.count))
        lastDeleted = nil
        undoTask?.cancel()
        save()
    }

    // MARK: Saving and loading

    private func replaceStored(_ track: Track) {
        if let i = tracks.firstIndex(where: { $0.id == track.id }) { tracks[i] = track }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Trailbook", isDirectory: true).appendingPathComponent("tracks.json")
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            var loaded = try JSONDecoder.withDates.decode([Track].self, from: data)
            // A track with no end time was being recorded when the app stopped. Keep it.
            var recovered = false
            for i in loaded.indices where loaded[i].end == nil {
                loaded[i].end = loaded[i].points.last?.time ?? loaded[i].start
                loaded[i].name += " (recovered)"
                recovered = true
            }
            tracks = loaded
            if recovered {
                notice = "The app closed while you were recording. Your track up to that point was kept."
                save()
            }
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("tracks.unreadable-\(stamp).json")
            try? fm.copyItem(at: fileURL, to: backup)
            tracks = []
            notice = "Your saved tracks could not be read. A copy was kept on this phone."
        }
    }

    private func save() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder.withDates.encode(tracks)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            notice = "Your track could not be saved to this phone. Free some storage, then try again."
        }
    }
}

extension JSONEncoder {
    static var withDates: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var withDates: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
