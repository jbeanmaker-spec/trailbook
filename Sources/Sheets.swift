import SwiftUI

// Pull-up menus in the style of the design: grabber, title with an underlined Cancel,
// capital-letter labels, an outlined field, and one big green button.

/// Chips that wrap onto more lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    private func layout(_ width: CGFloat, _ subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var frames: [CGRect] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            frames.append(CGRect(x: x, y: y, width: s.width, height: s.height))
            x += s.width + spacing
            rowH = max(rowH, s.height)
            maxX = max(maxX, x - spacing)
        }
        return (frames, CGSize(width: maxX, height: y + rowH))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal.width ?? 320, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = layout(bounds.width, subviews)
        for (v, f) in zip(subviews, r.frames) {
            v.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                    proposal: ProposedViewSize(f.size))
        }
    }
}

struct SheetTitleRow: View {
    let title: String
    let cancel: () -> Void
    var body: some View {
        HStack {
            Text(title).font(Theme.title).foregroundColor(Theme.ink)
            Spacer()
            Button(action: cancel) {
                Text("Cancel").font(Theme.heading).underline()
                    .foregroundColor(Theme.ink)
                    .frame(minHeight: Theme.tapMin)
            }
        }
    }
}

struct SheetLabel: View {
    let text: String
    init(_ t: String) { text = t }
    var body: some View {
        Text(text.uppercased()).font(Theme.label).tracking(1).foregroundColor(Theme.inkMuted)
    }
}

struct OutlinedField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}
    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.body)
            .focused(focused)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .padding(.horizontal, 12)
            .frame(minHeight: Theme.tapMin)
            .background(Theme.surface100)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd).stroke(Theme.ink, lineWidth: 2))
    }
}

struct Chip: View {
    let text: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(Theme.bodySm.weight(.bold))
                .padding(.horizontal, 14)
                .frame(minHeight: Theme.tapMin)
                .background(Theme.surface300)
                .foregroundColor(Theme.ink)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        }
    }
}

struct BigGreenButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Theme.heading)
                .frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                .background(Theme.forest.opacity(enabled ? 1 : 0.4))
                .foregroundColor(Theme.onForest)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        }
        .disabled(!enabled)
    }
}

extension View {
    /// The look of a pull-up menu.
    func pullUpStyle() -> some View {
        self
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Theme.radiusLg)
            .presentationBackground(Theme.surface200)
    }
}

// MARK: Add to a pack list group

enum PackSuggestions {
    static let builtIn: [String: [String]] = [
        "Water": ["Electrolyte tablets", "Water bladder", "Extra bottle", "Bleach drops"],
        "Shelter": ["Tarp", "Footprint", "Extra stakes", "Pillow"],
        "Fire": ["Firewood bundle", "Saw or hatchet", "Ferro rod", "Lantern"],
        "First aid": ["Tweezers", "Ibuprofen", "Tick remover", "Gauze"],
        "Food": ["Coffee", "Trail mix", "Tortillas", "Electrolyte drink mix"],
        "Navigation": ["Compass", "Trail map printout", "Charging cable", "Car charger"],
        "Light and tools": ["Lantern", "Camp saw", "Zip ties", "Paracord"],
        "Clothing": ["Rain pants", "Camp shoes", "Beanie", "Wool socks"],
        "Personal": ["Toothbrush", "Biodegradable soap", "Towel", "Sunglasses"],
    ]

    private static func key(_ group: String) -> String { "remembered.\(group)" }

    static func remembered(_ group: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(group)) ?? []
    }

    static func remember(_ item: String, in group: String) {
        var list = remembered(group)
        if !list.contains(where: { $0.lowercased() == item.lowercased() }) {
            list.append(item)
            UserDefaults.standard.set(list, forKey: key(group))
        }
    }

    static func suggestions(for group: String) -> [String] {
        remembered(group) + (builtIn[group] ?? ["Spare batteries", "Zip bags", "Duct tape", "Notebook"])
    }
}

struct PrepAddSheet: View {
    let groupTitle: String
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var remember = false
    @FocusState private var focused: Bool

    private var valid: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetTitleRow(title: "Add to \(groupTitle)") { dismiss() }
                VStack(alignment: .leading, spacing: 6) {
                    SheetLabel("Item")
                    OutlinedField(placeholder: "Item name", text: $text, focused: $focused, onSubmit: add)
                }
                VStack(alignment: .leading, spacing: 8) {
                    SheetLabel("Suggested for \(groupTitle)")
                    FlowLayout(spacing: 8) {
                        ForEach(PackSuggestions.suggestions(for: groupTitle), id: \.self) { s in
                            Chip(text: s) { text = s }
                        }
                    }
                }
                Toggle(isOn: $remember) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remember for future trips").font(Theme.body)
                        Text("Adds it to every new \(groupTitle) list")
                            .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    }
                }
                .frame(minHeight: Theme.tapMin)
                BigGreenButton(title: "Add to list", enabled: valid, action: add)
            }
            .padding(16)
        }
        .pullUpStyle()
        .onAppear { focused = true }
    }

    private func add() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        if remember { PackSuggestions.remember(t, in: groupTitle) }
        onAdd(t)
        dismiss()
    }
}

// MARK: Add a meal

struct SavedMeal: Identifiable {
    let name: String
    let note: String
    var id: String { name }
    static let all = [
        SavedMeal(name: "Foil-pack potatoes and sausage", note: "30 min · coals or stove"),
        SavedMeal(name: "Instant ramen with egg", note: "12 min · one pot"),
        SavedMeal(name: "Couscous with tuna", note: "10 min · one pot"),
        SavedMeal(name: "Oatmeal with raisins", note: "10 min · one pot"),
        SavedMeal(name: "Peanut butter wraps", note: "5 min · no cook"),
    ]
}

struct MealAddSheet: View {
    let day: Int
    let slot: MealSlot
    @EnvironmentObject private var meals: MealStore
    @EnvironmentObject private var trips: TripStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var note = ""
    @State private var servings = 2
    @FocusState private var focused: Bool

    private var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var dayName: String { MealStore.dayName(day) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetTitleRow(title: "Add to \(slot.title)") { dismiss() }
                VStack(alignment: .leading, spacing: 6) {
                    SheetLabel("Meal")
                    OutlinedField(placeholder: "Meal name", text: $name, focused: $focused, onSubmit: add)
                }
                VStack(alignment: .leading, spacing: 0) {
                    SheetLabel("Saved meals").padding(.bottom, 4)
                    ForEach(SavedMeal.all) { m in
                        Button { name = m.name; note = m.note } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.name).font(Theme.body.weight(.bold)).foregroundColor(Theme.ink)
                                    Text(m.note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                                }
                                Spacer()
                                Image(systemName: "plus").foregroundColor(Theme.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Theme.line)
                    }
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Servings").font(Theme.body)
                        Text("\(trips.current?.people ?? 2) people on this trip")
                            .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    }
                    Spacer()
                    stepButton("minus", "Fewer servings") { servings = max(1, servings - 1) }
                    Text("\(servings)").font(Theme.title).frame(minWidth: 32)
                    stepButton("plus", "More servings") { servings = min(20, servings + 1) }
                }
                BigGreenButton(title: "Add to \(dayName) \(slot.title.lowercased())", enabled: valid, action: add)
            }
            .padding(16)
        }
        .pullUpStyle()
        .onAppear { focused = true; servings = trips.current?.people ?? 2 }
    }

    private func stepButton(_ icon: String, _ label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold))
                .frame(width: 48, height: 48)
                .foregroundColor(Theme.ink)
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd).stroke(Theme.inkMuted, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private func add() {
        guard valid else { return }
        meals.add(name: name, note: note, day: day, slot: slot, servings: servings)
        dismiss()
    }
}
