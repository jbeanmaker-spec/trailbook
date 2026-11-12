import Foundation
import SwiftUI

/// Holds the pack list and saves it to the phone after every change.
/// Reliability rules from the design: works offline, never loses data on a bad file,
/// deletes can be undone.
@MainActor
final class PrepStore: ObservableObject {
    @Published private(set) var groups: [PrepGroup] = []
    @Published private(set) var lastDeleted: DeletedItem?
    /// Plain-words status shown on screen when something went wrong.
    @Published private(set) var notice: String?

    private let fileURL: URL
    private var undoTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? PrepStore.defaultFileURL()
        load()
    }

    // MARK: Counts

    var packedCount: Int { groups.reduce(0) { $0 + $1.items.filter(\.packed).count } }
    var totalCount: Int { groups.reduce(0) { $0 + $1.items.count } }

    // MARK: Changes

    func toggle(_ itemID: UUID) {
        mutateItem(itemID) { $0.packed.toggle() }
    }

    func add(title: String, to groupID: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let g = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[g].items.append(PrepItem(title: trimmed))
        save()
    }

    func assign(_ itemID: UUID, to name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        mutateItem(itemID) { $0.assignee = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }

    func delete(_ itemID: UUID) {
        for g in groups.indices {
            if let i = groups[g].items.firstIndex(where: { $0.id == itemID }) {
                let removed = groups[g].items.remove(at: i)
                lastDeleted = DeletedItem(item: removed, groupID: groups[g].id, index: i)
                save()
                startUndoTimer()
                return
            }
        }
    }

    func undoDelete() {
        guard let d = lastDeleted,
              let g = groups.firstIndex(where: { $0.id == d.groupID }) else { return }
        let index = min(d.index, groups[g].items.count)
        groups[g].items.insert(d.item, at: index)
        lastDeleted = nil
        undoTask?.cancel()
        save()
    }

    // MARK: Saving and loading

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Trailbook", isDirectory: true).appendingPathComponent("prep.json")
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            groups = SeedData.prepGroups()
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            groups = try JSONDecoder().decode([PrepGroup].self, from: data)
        } catch {
            // Keep the unreadable file so nothing is lost, then start from the default list.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent("prep.unreadable-\(stamp).json")
            try? fm.copyItem(at: fileURL, to: backup)
            groups = SeedData.prepGroups()
            notice = "Your saved list could not be read. A copy was kept and the default list is loaded."
            save()
        }
    }

    private func save() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(groups)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            notice = "Your last change could not be saved to this phone. Free some storage, then try again."
        }
    }

    private func mutateItem(_ itemID: UUID, _ change: (inout PrepItem) -> Void) {
        for g in groups.indices {
            if let i = groups[g].items.firstIndex(where: { $0.id == itemID }) {
                change(&groups[g].items[i])
                save()
                return
            }
        }
    }

    private func startUndoTimer() {
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.lastDeleted = nil
        }
    }
}
