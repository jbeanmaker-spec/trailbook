import SwiftUI

/// Stage 1: a fixed sample trip. Planning a trip and live weather arrive in later stages.
struct TripView: View {
    var body: some View {
        VStack(spacing: 0) {
            HeaderBand(
                label: "Fri Nov 13 → Sun Nov 15 · Missouri",
                title: "Ozark Highlands",
                left: "37.0842° N, 91.4417° W",
                right: "1,402 ft"
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SAMPLE FORECAST · NOT LIVE")
                        .font(Theme.label).tracking(1)
                        .foregroundColor(Theme.inkMuted)
                    HStack(spacing: 12) {
                        DayTile(day: "FRI", high: "58°", note: "Low 41°")
                        DayTile(day: "SAT", high: "54°", note: "Rain 1.4 in", selected: true)
                        DayTile(day: "SUN", high: "49°", note: "Low 33°")
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(Theme.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WATCH").font(Theme.label).tracking(1).foregroundColor(Theme.amber)
                            Text("Trails muddy Saturday morning. 1.4 in of rain overnight.")
                                .font(Theme.bodySm).foregroundColor(Theme.ink)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.amberBg)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                }
                .padding(16)
            }
        }
        .background(Theme.surface100.ignoresSafeArea())
    }
}

private struct DayTile: View {
    let day: String
    let high: String
    let note: String
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(day).font(Theme.label).tracking(1).foregroundColor(Theme.inkMuted)
            Text(high).font(.system(size: 44, weight: .bold)).foregroundColor(Theme.ink)
                .minimumScaleFactor(0.7)
            Text(note).font(Theme.bodySm).foregroundColor(Theme.inkMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface200)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLg)
                .stroke(selected ? Theme.ink : Theme.line, lineWidth: selected ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
    }
}
