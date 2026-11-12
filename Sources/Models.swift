import Foundation

struct PrepItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var note: String = ""
    var packed: Bool = false
    var assignee: String? = nil
}

struct PrepGroup: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var items: [PrepItem]
}

/// What was just deleted, kept for a few seconds so it can be undone.
struct DeletedItem: Equatable {
    let item: PrepItem
    let groupID: UUID
    let index: Int
}
