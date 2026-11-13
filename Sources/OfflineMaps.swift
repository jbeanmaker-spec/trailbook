import Foundation
import MapKit
import Combine

// Offline USGS topo maps for Missouri.
// Map data: USGS The National Map (public domain). Tiles come from the USGS Topo service,
// are saved on the phone one square at a time, and are read from the phone first, so the
// map works with no signal once an area is downloaded.

// MARK: Areas you can download

nonisolated struct Tile: Sendable, Equatable {
    let z: Int, x: Int, y: Int
}

nonisolated enum TileMath {
    static func x(lon: Double, z: Int) -> Int {
        let n = pow(2.0, Double(z))
        return min(Int(n) - 1, max(0, Int(floor((lon + 180) / 360 * n))))
    }
    static func y(lat: Double, z: Int) -> Int {
        let n = pow(2.0, Double(z))
        let r = lat * .pi / 180
        let v = (1 - asinh(tan(r)) / Double.pi) / 2 * n
        return min(Int(n) - 1, max(0, Int(floor(v))))
    }
    static func lon(x: Double, z: Int) -> Double { x / pow(2.0, Double(z)) * 360 - 180 }
    static func lat(y: Double, z: Int) -> Double {
        let n = Double.pi - 2 * Double.pi * y / pow(2.0, Double(z))
        return 180 / Double.pi * atan(0.5 * (exp(n) - exp(-n)))
    }
}

nonisolated struct MapRegion: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let minLat: Double, maxLat: Double, minLon: Double, maxLon: Double

    /// Zoom 9 (whole region) to 14 (trails and creeks).
    let zooms = 9...14

    static let all: [MapRegion] = [
        MapRegion(id: "ozarks", name: "Ozarks, Missouri",
                  subtitle: "Mark Twain National Forest, Current River, Meramec",
                  minLat: 36.8, maxLat: 38.3, minLon: -92.2, maxLon: -90.6),
        MapRegion(id: "east", name: "Eastern Missouri",
                  subtitle: "St. Louis to the Katy Trail",
                  minLat: 38.3, maxLat: 39.1, minLon: -91.8, maxLon: -90.0),
        MapRegion(id: "southwest", name: "Southwest Missouri",
                  subtitle: "Springfield, Table Rock Lake",
                  minLat: 36.5, maxLat: 37.5, minLon: -94.0, maxLon: -92.6),
        MapRegion(id: "northeast", name: "Northeast Missouri",
                  subtitle: "Hannibal, Mark Twain Lake",
                  minLat: 39.3, maxLat: 40.3, minLon: -92.4, maxLon: -91.2),
        MapRegion(id: "bootheel", name: "Missouri Bootheel",
                  subtitle: "Sikeston to Kennett",
                  minLat: 36.0, maxLat: 37.0, minLon: -90.3, maxLon: -89.4),
    ]

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
    }

    private func range(z: Int) -> (x: ClosedRange<Int>, y: ClosedRange<Int>) {
        let x0 = TileMath.x(lon: minLon, z: z), x1 = TileMath.x(lon: maxLon, z: z)
        let y0 = TileMath.y(lat: maxLat, z: z), y1 = TileMath.y(lat: minLat, z: z)
        return (min(x0, x1)...max(x0, x1), min(y0, y1)...max(y0, y1))
    }

    var tileCount: Int {
        zooms.reduce(0) { sum, z in let r = range(z: z); return sum + r.x.count * r.y.count }
    }

    /// A rough size, used before anything is downloaded.
    var estimatedBytes: Int64 { Int64(tileCount) * 24_000 }

    func allTiles() -> [Tile] {
        var out: [Tile] = []
        out.reserveCapacity(tileCount)
        for z in zooms {
            let r = range(z: z)
            for x in r.x { for y in r.y { out.append(Tile(z: z, x: x, y: y)) } }
        }
        return out
    }

    func contains(_ t: Tile) -> Bool {
        guard zooms.contains(t.z) else { return false }
        let lat = TileMath.lat(y: Double(t.y) + 0.5, z: t.z)
        let lon = TileMath.lon(x: Double(t.x) + 0.5, z: t.z)
        return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
    }
}

// MARK: Tiles on the phone

nonisolated enum TileStore {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Trailbook/tiles", isDirectory: true)
    }()

    static func fileURL(_ t: Tile) -> URL {
        root.appendingPathComponent("\(t.z)/\(t.x)_\(t.y).tile")
    }

    static func remoteURL(_ t: Tile) -> URL {
        URL(string: "https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/\(t.z)/\(t.y)/\(t.x)")!
    }

    static func read(_ t: Tile) -> Data? { try? Data(contentsOf: fileURL(t)) }

    static func exists(_ t: Tile) -> Bool { FileManager.default.fileExists(atPath: fileURL(t).path) }

    static func write(_ data: Data, _ t: Tile) throws {
        let url = fileURL(t)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static func remove(_ t: Tile) { try? FileManager.default.removeItem(at: fileURL(t)) }

    /// Downloads one tile unless it is already saved. Returns the bytes added, or nil on failure.
    static func fetch(_ t: Tile) async -> Int64? {
        if exists(t) { return 0 }
        var req = URLRequest(url: remoteURL(t))
        req.timeoutInterval = 20
        req.setValue("Trailbook/1.0 (personal camping app)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else { return nil }
            try write(data, t)
            return Int64(data.count)
        } catch {
            return nil
        }
    }
}

/// The map layer: tiles come from the phone first, then from the network when there is signal.
nonisolated final class CachedTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 3
        maximumZ = 16
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping @Sendable (Data?, Error?) -> Void) {
        let tile = Tile(z: path.z, x: path.x, y: path.y)
        if let data = TileStore.read(tile) {
            result(data, nil)
            return
        }
        var req = URLRequest(url: TileStore.remoteURL(tile))
        req.timeoutInterval = 15
        req.setValue("Trailbook/1.0 (personal camping app)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let http = resp as? HTTPURLResponse, http.statusCode == 200, let data, !data.isEmpty {
                result(data, nil)
            } else {
                result(nil, err ?? URLError(.badServerResponse))
            }
        }.resume()
    }
}

// MARK: Download progress, saved between launches

nonisolated struct RegionRecord: Codable, Equatable {
    var done: Int
    var total: Int
    var bytes: Int64
    var updated: Date?
    var complete: Bool

    var fraction: Double { total == 0 ? 0 : min(1, Double(done) / Double(total)) }
}

private nonisolated struct SavedMaps: Codable {
    var records: [String: RegionRecord]
}

final class MapStore: ObservableObject {
    @Published private(set) var records: [String: RegionRecord] = [:]
    @Published private(set) var downloading: String?
    @Published private(set) var notice: String?

    private var task: Task<Void, Never>?
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        fileURL = base.appendingPathComponent("Trailbook/maps.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(SavedMaps.self, from: data) {
            records = saved.records
        }
    }

    var totalBytes: Int64 { records.values.reduce(0) { $0 + $1.bytes } }

    var summary: String {
        totalBytes == 0 ? "Nothing saved" : "\(Self.size(totalBytes)) saved"
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func start(_ region: MapRegion) {
        guard downloading == nil else {
            notice = "One download at a time. Pause the current one first."
            return
        }
        notice = nil
        downloading = region.id
        task = Task { await run(region) }
    }

    func pause() {
        task?.cancel()
    }

    func delete(_ region: MapRegion) {
        if downloading == region.id { task?.cancel() }
        let others = MapRegion.all.filter { $0.id != region.id && records[$0.id] != nil }
        let tiles = region.allTiles()
        Task.detached {
            for t in tiles where !others.contains(where: { $0.contains(t) }) {
                TileStore.remove(t)
            }
        }
        records[region.id] = nil
        persist()
    }

    private func run(_ region: MapRegion) async {
        let tiles = region.allTiles()
        var rec = records[region.id] ?? RegionRecord(done: 0, total: tiles.count, bytes: 0, updated: nil, complete: false)
        rec.total = tiles.count
        rec.complete = false
        var done = 0
        var bytes = rec.bytes
        var badChunks = 0
        var missed = 0
        let chunk = 24
        var i = 0
        while i < tiles.count {
            if Task.isCancelled { break }
            let slice = Array(tiles[i..<min(i + chunk, tiles.count)])
            let r = await Self.fetch(slice)
            done += r.ok
            bytes += r.bytes
            missed += r.failed
            badChunks = r.ok == 0 ? badChunks + 1 : 0
            i += chunk
            rec.done = done
            rec.bytes = bytes
            records[region.id] = rec
            if badChunks >= 3 {
                notice = "No signal. Download paused. Tap Download to continue."
                break
            }
        }
        if done >= tiles.count {
            rec.complete = true
            rec.updated = Date()
            notice = nil
        } else if !Task.isCancelled && badChunks < 3 && missed > 0 {
            notice = "\(missed) map squares could not be saved. Tap Download to try again."
        }
        records[region.id] = rec
        downloading = nil
        persist()
    }

    private nonisolated static func fetch(_ slice: [Tile]) async -> (ok: Int, bytes: Int64, failed: Int) {
        await withTaskGroup(of: Int64?.self) { group in
            for t in slice { group.addTask { await TileStore.fetch(t) } }
            var ok = 0, failed = 0
            var bytes: Int64 = 0
            for await r in group {
                if let b = r { ok += 1; bytes += b } else { failed += 1 }
            }
            return (ok, bytes, failed)
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedMaps(records: records))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Tiles are still on the phone. Only the progress note is lost.
        }
    }
}
