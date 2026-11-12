import Combine
import Foundation

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Meal: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var note: String = ""
    var day: Int          // index into MealStore.tripDays
    var slot: MealSlot
    var servings: Int = 2
    var pack: [String] = []
}

struct ShoppingLine: Identifiable, Equatable {
    let item: String
    let usedIn: [String]
    var id: String { item.lowercased() }
}

private struct SavedMeals: Codable {
    var meals: [Meal]
    var bought: [String]
}

/// Holds the meal plan and saves it to the phone after every change.
/// Same rules as the pack list: works offline, keeps an unreadable file, deletes can be undone.
@MainActor
final class MealStore: ObservableObject {
    /// Sample trip days until trip planning is built.
    static let tripDays = ["Fri Nov 13", "Sat Nov 14", "Sun Nov 15"]

    @Published private(set) var meals: [Meal] = []
    @Published private(set) var bought: Set<String> = []
    @Published private(set) var lastDeleted: Meal?
    @Published private(set) var notice: String?

    private let fileURL: URL
    private var undoTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("Trailbook", isDirectory: true)
                .appendingPathComponent("meals.json")
        }
        load()
    }

    // MARK: Reading

    func meals(day: Int, slot: MealSlot) -> [Meal] {
        meals.filter { $0.day == day && $0.slot == slot }
    }

    func meal(_ id: UUID) -> Meal? { meals.first { $0.id == id } }

    var shopping: [ShoppingLine] {
        var order: [String] = []
        var names: [String: String] = [:]
        var users: [String: [String]] = [:]
        for m in meals {
            for item in m.pack {
                let k = item.lowercased()
                if names[k] == nil { names[k] = item; order.append(k) }
                if !(users[k] ?? []).contains(m.name) { users[k, default: []].append(m.name) }
            }
        }
        return order.map { ShoppingLine(item: names[$0] ?? $0, usedIn: users[$0] ?? []) }
    }

    func isBought(_ line: ShoppingLine) -> Bool { bought.contains(line.id) }

    // MARK: Changes

    @discardableResult
    func add(name: String, day: Int, slot: MealSlot, servings: Int = 2, pack: [String] = []) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return nil }
        let m = Meal(name: n, day: day, slot: slot, servings: servings, pack: pack)
        meals.append(m)
        save()
        return m.id
    }

    func addPack(_ item: String, to mealID: UUID) {
        let t = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = meals.firstIndex(where: { $0.id == mealID }) else { return }
        if !meals[i].pack.contains(where: { $0.lowercased() == t.lowercased() }) {
            meals[i].pack.append(t)
            save()
        }
    }

    func removePack(_ item: String, from mealID: UUID) {
        guard let i = meals.firstIndex(where: { $0.id == mealID }) else { return }
        meals[i].pack.removeAll { $0 == item }
        save()
    }

    func setServings(_ n: Int, for mealID: UUID) {
        guard let i = meals.firstIndex(where: { $0.id == mealID }) else { return }
        meals[i].servings = max(1, min(n, 20))
        save()
    }

    func toggleBought(_ line: ShoppingLine) {
        if bought.contains(line.id) { bought.remove(line.id) } else { bought.insert(line.id) }
        save()
    }

    func delete(_ mealID: UUID) {
        guard let i = meals.firstIndex(where: { $0.id == mealID }) else { return }
        lastDeleted = meals.remove(at: i)
        save()
        undoTask?.cancel()
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.lastDeleted = nil
        }
    }

    func undoDelete() {
        guard let m = lastDeleted else { return }
        meals.append(m)
        lastDeleted = nil
        undoTask?.cancel()
        save()
    }

    // MARK: Saving and loading

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            meals = MealStore.sampleMeals()
            save()
            return
        }
        do {
            let saved = try JSONDecoder().decode(SavedMeals.self, from: Data(contentsOf: fileURL))
            meals = saved.meals
            bought = Set(saved.bought)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("meals.unreadable-\(stamp).json")
            try? fm.copyItem(at: fileURL, to: backup)
            meals = MealStore.sampleMeals()
            notice = "Your saved meals could not be read. A copy was kept and the sample plan is loaded."
            save()
        }
    }

    private func save() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedMeals(meals: meals, bought: Array(bought)))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            notice = "Your last change could not be saved to this phone. Free some storage, then try again."
        }
    }

    /// Sample recipes from the design. Replace them with your own.
    private static func sampleMeals() -> [Meal] {
        [
            Meal(name: "Oatmeal with raisins", note: "10 min · one pot", day: 1, slot: .breakfast,
                 pack: ["Instant oatmeal", "Raisins"]),
            Meal(name: "Chili with rice", note: "25 min · one pot", day: 1, slot: .dinner,
                 pack: ["Dehydrated chili", "Instant rice", "Hot sauce"]),
        ]
    }
}
