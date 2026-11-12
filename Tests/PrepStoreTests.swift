import XCTest
@testable import Trailbook

@MainActor
final class PrepStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("prep.json")
    }

    func testSeedHasFortyItemsInTenGroups() {
        let store = PrepStore(fileURL: tempURL())
        XCTAssertEqual(store.groups.count, 10)
        XCTAssertEqual(store.totalCount, 40)
    }

    func testChangesSurviveRelaunch() {
        let url = tempURL()
        var store: PrepStore? = PrepStore(fileURL: url)
        let id = store!.groups[1].items[0].id
        store!.toggle(id)
        store!.add(title: "Camp chair", to: store!.groups[1].id)
        store = nil
        let reloaded = PrepStore(fileURL: url)
        XCTAssertEqual(reloaded.packedCount, 1)
        XCTAssertEqual(reloaded.totalCount, 41)
    }

    func testDeleteThenUndoRestoresPosition() {
        let store = PrepStore(fileURL: tempURL())
        let item = store.groups[2].items[1]
        store.delete(item.id)
        XCTAssertEqual(store.totalCount, 39)
        store.undoDelete()
        XCTAssertEqual(store.groups[2].items[1].id, item.id)
    }

    func testCorruptFileKeepsACopyAndLoadsDefaults() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = PrepStore(fileURL: url)
        XCTAssertEqual(store.totalCount, 40)
        XCTAssertNotNil(store.notice)
        let files = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        XCTAssertTrue(files.contains { $0.hasPrefix("prep.unreadable-") })
    }

    func testBlankItemIsIgnored() {
        let store = PrepStore(fileURL: tempURL())
        store.add(title: "   ", to: store.groups[0].id)
        XCTAssertEqual(store.totalCount, 40)
    }
}
