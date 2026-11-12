import SwiftUI

/// "Plan a trip": name, place, dates and people. Saves the trip and makes it the current one.
struct PlanTripView: View {
    @EnvironmentObject private var trips: TripStore
    @EnvironmentObject private var gps: LocationService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var spotName = Spot.missouri[0].name
    @State private var useMyLocation = false
    @State private var start = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var people = 2
    @FocusState private var focused: Bool

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
                        ForEach(Spot.missouri) { Text($0.name).tag($0.name) }
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
            }
            .navigationTitle("Plan a trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        let spot = Spot.missouri.first { $0.name == spotName } ?? Spot.missouri[0]
        var lat = spot.latitude, lon = spot.longitude
        var place = spot.name
        if useMyLocation, let l = gps.location {
            lat = l.coordinate.latitude; lon = l.coordinate.longitude
            place = "My location"
        }
        trips.add(Trip(name: name.trimmingCharacters(in: .whitespaces), place: place,
                       latitude: lat, longitude: lon, start: start, end: end, people: people))
        dismiss()
    }
}
