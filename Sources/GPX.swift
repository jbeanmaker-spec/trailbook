import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Writes a track as a standard GPX 1.1 file. Garmin devices and apps read this format.
enum GPX {
    static func string(for track: Track) -> String {
        let iso = ISO8601DateFormatter()
        var out = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Trailbook" xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(escape(track.name))</name>
            <trkseg>

        """
        for p in track.points {
            out += "      <trkpt lat=\"\(p.lat)\" lon=\"\(p.lon)\"><ele>\(p.ele)</ele><time>\(iso.string(from: p.time))</time></trkpt>\n"
        }
        out += """
            </trkseg>
          </trk>
        </gpx>

        """
        return out
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

extension UTType {
    static let gpx = UTType(filenameExtension: "gpx", conformingTo: .xml) ?? .xml
}

/// What the Share button hands to the system: a real .gpx file.
struct GPXFile: Transferable {
    let track: Track

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gpx) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.track.fileName)
            try GPX.string(for: item.track).write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
