import SwiftUI

/// "Plan a trip" (new) or "Trip details" (editing one): name, place, dates and people.
struct PlanTripView: View {
    /// Pass a trip to edit it. Leave nil to plan a new one.
    var editing: Trip? = nil

    @EnvironmentObject private var trips: TripStore
    @EnvironmentObject private var gps: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var spotName: String
    @State private var useMyLocation = false
    @State private var start: Date
    @State private var end: Date
    @State private var people: Int
    @State private var confirmDelete = false
    @FocusState private var focused: Bool
    /// A saved place that is not on the preset list (for example "My location").
    private let savedPlace: Spot?

    init(editing: Trip? = nil) {
        self.editing = editing
        if let t = editing {
            _name = State(initialValue: t.name)
            _spotName = State(initialValue: t.place)
            _start = State(initialValue: t.start)
            _end = State(initialValue: t.end)
            _people = State(initialValue: t.people)
            let known = Spot.missouri.contains { $0.name == t.place }
            savedPlace = known ? nil : Spot(name: t.place, latitude: t.latitude, longitude: t.longitude)
        } else {
            _name = State(initialValue: "")
            _spotName = State(initialValue: Spot.missouri[0].name)
            _start = State(initialValue: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            _end = State(initialValue: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
            _people = State(initialValue: 2)
            savedPlace = nil
        }
    }

    private var spots: [Spot] {
        if let s = savedPlace { return [s] + Spot.missouri }
        return Spot.missouri
    }

    private var nights: Int {
        let cal = Calendar.current
        return max(0, cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: end)).day ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip name") {
                    TextField("For example, Shut-Ins weekend", text: $name)
                        .focused($focused).frame(minHeight: Theme.tapMin)
                }
                Section("Where") {
                    Picker("Place", selection: $spotName) {
                        ForEach(spots) { Text($0.name).tag($0.name) }
                    }
                    .disabled(useMyLocation)
                    Toggle("Use my current location", isOn: $useMyLocation)
                        .disabled(gps.location == nil)
                    if gps.location == nil {
                        Text("Open the Track page once so the phone can find you.")
                            .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                    }
                    Text("Coordinates are approximate. Check the exact spot before you go.")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
                Section("When") {
                    DatePicker("Leave", selection: $start, displayedComponents: .date)
                        .frame(minHeight: Theme.tapMin)
                        .onChange(of: start) { _, new in if end < new { end = new } }
                    DatePicker("Back", selection: $end, in: start..., displayedComponents: .date)
                        .frame(minHeight: Theme.tapMin)
                    Text("\(nights) night\(nights == 1 ? "" : "s")")
                        .font(Theme.bodySm).foregroundColor(Theme.inkMuted)
                }
                Section {
                    Stepper("People: \(people)", value: $people, in: 1...20)
                        .frame(minHeight: Theme.tapMin)
                }
                if editing != nil {
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Delete this trip", systemImage: "trash")
                                .frame(maxWidth: .infinity, minHeight: Theme.tapMin, alignment: .leading)
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Plan a trip" : "Trip details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = editing == nil }
            .confirmationDialog("Delete this trip?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete trip", role: .destructive) {
                    if let t = editing { trips.delete(t.id) }
                    dismiss()
                }
                Button("Keep it", role: .cancel) {}
            }
        }
    }

    private func save() {
        let spot = spots.first { $0.name == spotName } ?? Spot.missouri[0]
        var lat = spot.latitude, lon = spot.longitude
        var place = spot.name
        if useMyLocation, let l = gps.location {
            lat = l.coordinate.latitude; lon = l.coordinate.longitude
            place = "My location"
        }
        let clean = name.trimmingCharacters(in: .whitespaces)
        if var t = editing {
            t.name = clean; t.place = place; t.latitude = lat; t.longitude = lon
            t.start = start; t.end = end; t.people = people
            trips.update(t)
        } else {
            trips.add(Trip(name: clean, place: place, latitude: lat, longitude: lon,
                           start: start, end: end, people: people))
        }
        dismiss()
    }
}
