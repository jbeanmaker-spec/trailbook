import SwiftUI

struct PrepView: View {
    @EnvironmentObject private var store: PrepStore
    @State private var addTarget: PrepGroup?
    @State private var assignTarget: PrepItem?
    @State private var mealTarget: PrepItem?

    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Prep · Fri Nov 13 → Sun Nov 15",
                title: "Pack list",
                left: "\(store.packedCount) of \(store.totalCount) packed",
                right: "2 nights"
            )
            if let notice = store.notice {
                Text(notice)
                    .font(Theme.bodySm)
                    .foregroundColor(Theme.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.amberBg)
            }
            List {
                Text("Swipe a row right to delete it, left to assign it. Food items also have To meal.")
                    .font(Theme.bodySm)
                    .foregroundColor(Theme.inkMuted)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(store.groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            PrepRow(item: item) { store.toggle(item.id) }
                                .listRowBackground(Theme.surface200)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.delete(item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(Theme.redOrange)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        assignTarget = item
                                    } label: {
                                        Label("Assign", systemImage: "person.badge.plus")
                                    }
                                    .tint(Theme.sky)
                                    if group.title == "Food" {
                                        Button {
                                            mealTarget = item
                                        } label: {
                                            Label("To meal", systemImage: "fork.knife")
                                        }
                                        .tint(Theme.ember)
                                    }
                                }
                        }
                    } header: {
                        GroupHeader(group: group) { addTarget = group }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.surface100.ignoresSafeArea())
        .overlay(alignment: .bottom) { undoBar }
        .animation(.easeInOut(duration: 0.2), value: store.lastDeleted)
        .sheet(item: $addTarget) { group in
            AddItemSheet(groupTitle: group.title) { title in
                store.add(title: title, to: group.id)
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $mealTarget) { item in
            SendToMealSheet(itemTitle: item.title)
                .presentationDetents([.large])
        }
        .sheet(item: $assignTarget) { item in
            AssignSheet(itemTitle: item.title, current: item.assignee) { name in
                store.assign(item.id, to: name)
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder private var undoBar: some View {
        if let deleted = store.lastDeleted {
            HStack {
                Text("Deleted “\(deleted.item.title)”")
                    .font(Theme.body)
                    .lineLimit(1)
                Spacer()
                Button("Undo") { store.undoDelete() }
                    .font(Theme.heading)
                    .frame(minHeight: Theme.tapMin)
            }
            .padding(.horizontal, 16)
            .background(Theme.ink)
            .foregroundColor(Theme.surface100)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
            .padding(16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private struct GroupHeader: View {
    let group: PrepGroup
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(group.title.uppercased())
                .font(Theme.label).tracking(1)
                .foregroundColor(Theme.ink)
            Text("\(group.items.filter(\.packed).count) of \(group.items.count)")
                .font(Theme.bodySm)
                .foregroundColor(Theme.inkMuted)
            Spacer()
            Button(action: onAdd) {
                Label("Add", systemImage: "plus")
                    .font(Theme.bodySm.weight(.bold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: Theme.tapMin)
            }
            .accessibilityLabel("Add to \(group.title)")
        }
        .textCase(nil)
    }
}

private struct PrepRow: View {
    let item: PrepItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.packed ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundColor(item.packed ? Theme.forest : Theme.inkMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Theme.body)
                        .foregroundColor(Theme.ink)
                        .strikethrough(item.packed, color: Theme.inkMuted)
                    if !item.note.isEmpty {
                        Text(item.note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    }
                    if let who = item.assignee {
                        Text("Assigned to \(who)").font(Theme.bodySm.weight(.bold)).foregroundColor(Theme.sky)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Theme.tapMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(item.packed ? .isSelected : [])
        .accessibilityHint("Double tap to mark as \(item.packed ? "not packed" : "packed")")
    }
}

private struct AddItemSheet: View {
    let groupTitle: String
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Item name", text: $text)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .frame(minHeight: Theme.tapMin)
            }
            .navigationTitle("Add to \(groupTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func add() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onAdd(text)
        dismiss()
    }
}

private struct AssignSheet: View {
    let itemTitle: String
    let current: String?
    let onAssign: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Who is bringing “\(itemTitle)”?") {
                    TextField("Name", text: $name)
                        .frame(minHeight: Theme.tapMin)
                }
                if current != nil {
                    Button("Clear assignment", role: .destructive) {
                        onAssign(nil)
                        dismiss()
                    }
                    .frame(minHeight: Theme.tapMin)
                }
            }
            .navigationTitle("Assign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        onAssign(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { name = current ?? "" }
        }
    }
}
