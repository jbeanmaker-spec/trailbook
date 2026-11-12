import Foundation
import CoreLocation

struct TrackPoint: Codable, Equatable {
    var lat: Double
    var lon: Double
    var ele: Double      // meters
    var time: Date
    var acc: Double      // horizontal accuracy, meters
}

struct Track: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var start: Date
    var end: Date?
    var points: [TrackPoint] = []

    var distanceMeters: Double {
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            let a = CLLocation(latitude: points[i - 1].lat, longitude: points[i - 1].lon)
            let b = CLLocation(latitude: points[i].lat, longitude: points[i].lon)
            total += b.distance(from: a)
        }
        return total
    }

    var fileName: String {
        let safe = name.map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined()
        return "\(safe).gpx"
    }
}
