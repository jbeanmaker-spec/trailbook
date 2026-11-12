import Foundation

/// The essentials list from the design: 40 items in 10 groups.
/// "Added for the forecast" is fixed sample data until weather is connected.
enum SeedData {
    static func prepGroups() -> [PrepGroup] {
        func g(_ title: String, _ items: [(String, String)]) -> PrepGroup {
            PrepGroup(title: title, items: items.map { PrepItem(title: $0.0, note: $0.1) })
        }
        return [
            g("Added for the forecast", [
                ("Rain shell", "Rain Saturday, 1.4 in"),
                ("Tarp over the kitchen", "Cook dry in the rain"),
                ("Warm hat and gloves", "Low 33° Sunday"),
            ]),
            g("Shelter", [
                ("Tent, poles and stakes", ""),
                ("Ground sheet", ""),
                ("Sleeping bag rated for 30°", ""),
                ("Sleeping pad", ""),
            ]),
            g("Water", [
                ("Water filter", ""),
                ("Two 1 L bottles", ""),
                ("Collapsible 2 L carry bag", ""),
                ("Purification tablets", "Backup if the filter fails"),
            ]),
            g("Fire", [
                ("Lighter", ""),
                ("Waterproof matches", ""),
                ("Fire starter", ""),
                ("Stove and fuel canister", ""),
                ("Fire restrictions checked", "Check the land manager before you go"),
            ]),
            g("First aid", [
                ("First aid kit", ""),
                ("Blister care", ""),
                ("Personal medicine", ""),
                ("Emergency blanket", ""),
                ("Whistle", ""),
            ]),
            g("Food", [
                ("Meals for 3 days", "From the Meal plan"),
                ("Extra day of food", "Snacks and a spare dinner"),
                ("Cook pot and spork", ""),
                ("Food bag and rope", "Hang it, away from camp"),
            ]),
            g("Navigation", [
                ("Paper map of the area", "In case the phone fails"),
                ("Offline map downloaded", "Ozark Highlands, 184 MB"),
                ("Battery pack and cable", ""),
                ("Told someone my plan", "Where, and when you are back"),
            ]),
            g("Light and tools", [
                ("Headlamp", ""),
                ("Spare batteries", ""),
                ("Knife or multi-tool", ""),
                ("Repair tape", ""),
            ]),
            g("Clothing", [
                ("Insulating layer", ""),
                ("Extra socks", ""),
                ("Sun hat and sunscreen", ""),
            ]),
            g("Personal", [
                ("Toilet paper and trowel", ""),
                ("Trash bags", "Pack it out"),
                ("Insect repellent", ""),
                ("Hand sanitizer", ""),
            ]),
        ]
    }
}
