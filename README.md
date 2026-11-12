# Trailbook, stage 1

SwiftUI app for iPhone (iOS 17 or newer). Stage 1 has: the five-tab shell, Trip (sample data), Prep (the 40-item pack list, saved on the phone), and Compass. Maps and Meals are placeholders.

Written without a compiler. Expect to fix a few small build errors on the first run; paste them to Claude.

## Set up in Xcode
1. Install Xcode from the Mac App Store, open it once and accept the licence.
2. File > New > Project > iOS > App. Product name `Trailbook`, interface SwiftUI, language Swift. Tick "Include Tests" is optional.
3. Delete the generated `TrailbookApp.swift` and `ContentView.swift`.
4. Drag every file from the `Sources` folder into the project (tick "Copy items if needed"). Drag `Tests/PrepStoreTests.swift` into the test target if you made one.
5. Project settings > Trailbook target > Minimum Deployments: iOS 17.0.
6. Pick your iPhone (or an iPhone Simulator) and press Run. The Simulator has no compass; use a real phone for that tab.

## What to check
- Prep: tap a row to pack it; swipe right to delete, then Undo; swipe left to assign; "+ Add" on a group adds an item. Close and reopen the app: changes stay. Turn on airplane mode: still works.
- Compass: the dial turns as you turn the phone. Calibrate with a figure 8 if asked.
- Trip: sample data only.
- Run the tests (Cmd U): five should pass.

## Not done yet
Live weather, GPS, offline maps, Garmin export, satellite, Meals, plan-a-trip.
