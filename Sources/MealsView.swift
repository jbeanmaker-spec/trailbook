import SwiftUI

struct MealsView: View {
    @EnvironmentObject private var meals: MealStore
    @State private var addTarget: AddTarget?

    struct AddTarget: Identifiable {
        let day: Int
        let slot: MealSlot
        var id: String { "\(day)-\(slot.rawValue)" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderBand(
                    label: "Meals · 3 days · 2 nights",
                    title: "Meal plan",
                    left: "\(meals.meals.count) meals planned",
                    right: "Cook on a stove"
                )
                if let notice = meals.notice {
                    Text(notice)
                        .font(Theme.bodySm).foregroundColor(Theme.ink)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.amberBg)
                }
                List {
                    Section {
                        NavigationLink {
                            ShoppingView()
                        } label: {
                            Label("Trip shopping list · \(meals.shopping.count) items", systemImage: "cart")
                                .font(Theme.heading)
                                .frame(minHeight: Theme.tapMin)
                        }
                        .listRowBackground(Theme.surface200)
                    }
                    ForEach(MealStore.tripDays.indices, id: \.self) { day in
                        ForEach(MealSlot.allCases) { slot in
                            Section {
                                ForEach(meals.meals(day: day, slot: slot)) { meal in
                                    NavigationLink {
                                        MealDetailView(mealID: meal.id)
                                    } label: {
                                        MealRow(meal: meal)
                                    }
                                    .listRowBackground(Theme.surface200)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button(role: .destructive) { meals.delete(meal.id) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(Theme.redOrange)
                                    }
                                }
                            } header: {
                                SlotHeader(day: MealStore.tripDays[day], slot: slot) {
                                    addTarget = AddTarget(day: day, slot: slot)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.surface100.ignoresSafeArea())
            .overlay(alignment: .bottom) { undoBar }
            .animation(.easeInOut(duration: 0.2), value: meals.lastDeleted)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $addTarget) { t in
                AddMealSheet(day: t.day, slot: t.slot)
                    .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder private var undoBar: some View {
        if let deleted = meals.lastDeleted {
            HStack {
                Text("Deleted “\(deleted.name)”").font(Theme.body).lineLimit(1)
                Spacer()
                Button("Undo") { meals.undoDelete() }
                    .font(Theme.heading).frame(minHeight: Theme.tapMin)
            }
            .padding(.horizontal, 16)
            .background(Theme.ink).foregroundColor(Theme.surface100)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private struct SlotHeader: View {
    let day: String
    let slot: MealSlot
    let onAdd: () -> Void
    var body: some View {
        HStack {
            Text("\(day) · \(slot.title)".uppercased())
                .font(Theme.label).tracking(1).foregroundColor(Theme.ink)
            Spacer()
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .font(Theme.bodySm.weight(.bold))
                    .padding(.horizontal, 12).frame(minHeight: Theme.tapMin)
            }
            .accessibilityLabel("Add to \(day) \(slot.title)")
        }
        .textCase(nil)
    }
}

private struct MealRow: View {
    let meal: Meal
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(meal.name).font(Theme.heading).foregroundColor(Theme.ink)
            if !meal.note.isEmpty {
                Text(meal.note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            if !meal.pack.isEmpty {
                Text("Pack: " + meal.pack.joined(separator: ", "))
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
        }
        .frame(minHeight: Theme.tapMin, alignment: .leading)
    }
}

// MARK: Add a meal

private struct AddMealSheet: View {
    let day: Int
    let slot: MealSlot
    @EnvironmentObject private var meals: MealStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var servings = 2
    @FocusState private var focused: Bool

    private let saved = [
        "Foil-pack potatoes and sausage", "Instant ramen with egg", "Couscous with tuna",
        "Oatmeal with raisins", "Peanut butter wraps",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Meal name", text: $name)
                        .focused($focused).frame(minHeight: Theme.tapMin)
                }
                Section("Saved meals") {
                    ForEach(saved, id: \.self) { s in
                        Button { name = s } label: {
                            Text(s).frame(maxWidth: .infinity, minHeight: Theme.tapMin, alignment: .leading)
                        }
                    }
                }
                Section {
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                        .frame(minHeight: Theme.tapMin)
                }
            }
            .navigationTitle("Add to \(MealStore.tripDays[day]) \(slot.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        meals.add(name: name, day: day, slot: slot, servings: servings)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

// MARK: Meal detail

struct MealDetailView: View {
    let mealID: UUID
    @EnvironmentObject private var meals: MealStore
    @State private var newItem = ""

    var body: some View {
        if let meal = meals.meal(mealID) {
            List {
                Section {
                    Text("\(MealStore.tripDays[meal.day]) · \(meal.slot.title)")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    Stepper("Servings: \(meal.servings)",
                            value: Binding(get: { meal.servings }, set: { meals.setServings($0, for: mealID) }),
                            in: 1...20)
                        .frame(minHeight: Theme.tapMin)
                }
                Section("Pack for this meal") {
                    if meal.pack.isEmpty {
                        Text("Nothing yet. Add items below, or send them from the pack list.")
                            .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    }
                    ForEach(meal.pack, id: \.self) { item in
                        Text(item).frame(minHeight: Theme.tapMin, alignment: .leading)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(role: .destructive) { meals.removePack(item, from: mealID) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .tint(Theme.redOrange)
                            }
                    }
                    HStack {
                        TextField("Add an item", text: $newItem)
                            .submitLabel(.done).onSubmit(addItem)
                            .frame(minHeight: Theme.tapMin)
                        Button("Add", action: addItem)
                            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("This meal was deleted.").padding()
        }
    }

    private func addItem() {
        meals.addPack(newItem, to: mealID)
        newItem = ""
    }
}

// MARK: Trip shopping list

struct ShoppingView: View {
    @EnvironmentObject private var meals: MealStore
    var body: some View {
        List {
            if meals.shopping.isEmpty {
                Text("Items you add to meals show up here.")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            ForEach(meals.shopping) { line in
                Button { meals.toggleBought(line) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: meals.isBought(line) ? "checkmark.square.fill" : "square")
                            .font(.system(size: 24))
                            .foregroundColor(meals.isBought(line) ? Theme.forest : Theme.inkMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.item).font(Theme.body).foregroundColor(Theme.ink)
                                .strikethrough(meals.isBought(line), color: Theme.inkMuted)
                            Text(line.usedIn.joined(separator: ", "))
                                .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: Theme.tapMin)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Shopping list")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Send a pack-list item to a meal

struct SendToMealSheet: View {
    let itemTitle: String
    @EnvironmentObject private var meals: MealStore
    @Environment(\.dismiss) private var dismiss
    @State private var day = 1
    @State private var slot = MealSlot.dinner
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Send “\(itemTitle)” to") {
                    Picker("Day", selection: $day) {
                        ForEach(MealStore.tripDays.indices, id: \.self) { i in
                            Text(String(MealStore.tripDays[i].prefix(3))).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { s in Text(s.title).tag(s) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("\(MealStore.tripDays[day]) \(slot.title.lowercased())") {
                    ForEach(meals.meals(day: day, slot: slot)) { m in
                        Button {
                            meals.addPack(itemTitle, to: m.id)
                            dismiss()
                        } label: {
                            Text(m.name).frame(maxWidth: .infinity, minHeight: Theme.tapMin, alignment: .leading)
                        }
                    }
                    HStack {
                        TextField("New meal with this item", text: $newName)
                            .frame(minHeight: Theme.tapMin)
                        Button("Add") {
                            if let id = meals.add(name: newName, day: day, slot: slot) {
                                meals.addPack(itemTitle, to: id)
                                dismiss()
                            }
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Text("The item stays on your pack list. It also shows in the meal and on the trip shopping list.")
                    .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
            }
            .navigationTitle("Send to a meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
