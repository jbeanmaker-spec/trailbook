import XCTest
import CoreLocation
@testable import Trailbook

@MainActor
final class TrackStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("tracks.json")
    }

    private func fix(_ lat: Double, _ lon: Double, acc: Double = 5) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                   altitude: 300, horizontalAccuracy: acc, verticalAccuracy: 5, timestamp: Date())
    }

    func testRecordsMovementAndIgnoresStillnessAndBadFixes() {
        let store = TrackStore(fileURL: tempURL())
        store.startRecording(name: "Test")
        store.add(fix(37.0000, -91.0000))
        store.add(fix(37.0000, -91.0000))            // same spot: skipped
        store.add(fix(37.0010, -91.0000, acc: 200))  // too inaccurate: skipped
        store.add(fix(37.0010, -91.0000))            // about 111 m north: kept
        XCTAssertEqual(store.recording?.points.count, 2)
        XCTAssertGreaterThan(store.recording?.distanceMeters ?? 0, 100)
    }

    func testSavedTrackSurvivesRelaunch() {
        let url = tempURL()
        var store: TrackStore? = TrackStore(fileURL: url)
        store!.startRecording(name: "Loop")
        store!.add(fix(37.0, -91.0))
        store!.add(fix(37.001, -91.0))
        store!.stopRecording()
        store = nil
        let reloaded = TrackStore(fileURL: url)
        XCTAssertEqual(reloaded.tracks.count, 1)
        XCTAssertEqual(reloaded.tracks[0].points.count, 2)
        XCTAssertNotNil(reloaded.tracks[0].end)
    }

    func testRecordingInterruptedByCrashIsRecovered() {
        let url = tempURL()
        var store: TrackStore? = TrackStore(fileURL: url)
        store!.startRecording(name: "Crash")   // saved at start, never stopped
        store = nil
        let reloaded = TrackStore(fileURL: url)
        XCTAssertEqual(reloaded.tracks.count, 1)
        XCTAssertTrue(reloaded.tracks[0].name.contains("recovered"))
        XCTAssertNil(reloaded.recording)
        XCTAssertNotNil(reloaded.notice)
    }

    func testDeleteAndUndo() {
        let store = TrackStore(fileURL: tempURL())
        store.startRecording(name: "A"); store.stopRecording()
        let id = store.tracks[0].id
        store.delete(id)
        XCTAssertTrue(store.tracks.isEmpty)
        store.undoDelete()
        XCTAssertEqual(store.tracks.first?.id, id)
    }

    func testGPXContainsPointsAndEscapesName() {
        var t = Track(name: "Bluff & <Creek>", start: Date())
        t.points = [TrackPoint(lat: 37.5, lon: -91.25, ele: 310, time: Date(), acc: 5)]
        let xml = GPX.string(for: t)
        XCTAssertTrue(xml.contains("lat=\"37.5\" lon=\"-91.25\""))
        XCTAssertTrue(xml.contains("Bluff &amp; &lt;Creek&gt;"))
        XCTAssertTrue(xml.contains("<gpx version=\"1.1\""))
    }
}
