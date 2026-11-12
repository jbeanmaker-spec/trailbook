import SwiftUI
import MessageUI
import CoreLocation

/// Wraps the system Messages composer. The iPhone's own Messages app
/// handles sending, including by satellite where the iPhone supports it.
struct MessageComposer: UIViewControllerRepresentable {
    let body: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish) }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(_ f: @escaping () -> Void) { onFinish = f }
        func messageComposeViewController(_ c: MFMessageComposeViewController,
                                          didFinishWith result: MessageComposeResult) {
            c.dismiss(animated: true) { self.onFinish() }
        }
    }
}

struct CheckinView: View {
    @EnvironmentObject private var gps: LocationService
    @State private var note = "I'm OK."
    @State private var composing = false

    private var message: String {
        let time = Date().formatted(date: .abbreviated, time: .shortened)
        guard let l = gps.location else { return "\(note) (\(time), no GPS fix yet)" }
        let lat = String(format: "%.5f", l.coordinate.latitude)
        let lon = String(format: "%.5f", l.coordinate.longitude)
        let acc = Int(l.horizontalAccuracy * 3.28084)
        return "\(note)\nTrailbook check-in \(time)\n\(lat), \(lon) (±\(acc) ft)\nhttps://maps.apple.com/?ll=\(lat),\(lon)&q=Check-in"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CHECK-IN").font(Theme.label).foregroundStyle(Theme.ember)
                    Text("Send a check-in").font(Theme.display).foregroundStyle(Theme.surface100)
                    Text("Opens your Messages with your location filled in.")
                        .foregroundStyle(Theme.surface100)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.ink)

                VStack(alignment: .leading, spacing: 12) {
                    Text("MESSAGE").font(Theme.label).foregroundStyle(Theme.inkMuted)
                    TextField("Message", text: $note)
                        .textFieldStyle(.roundedBorder).frame(minHeight: Theme.tapMin)
                    Text(message).font(.system(.callout, design: .monospaced))
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface200)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
                    Button {
                        composing = true
                    } label: {
                        Text("Open in Messages").font(Theme.heading)
                            .frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!MFMessageComposeViewController.canSendText())
                    ShareLink(item: message) {
                        Text("Share another way").frame(maxWidth: .infinity, minHeight: Theme.tapMin)
                    }
                    if !MFMessageComposeViewController.canSendText() {
                        Text("This device can't send texts (the Simulator can't). Use Share instead.")
                            .font(.footnote).foregroundStyle(Theme.inkMuted)
                    }
                    Text("With no cell signal, Messages on an iPhone 14 or newer can offer satellite texting from the message screen. Point at the sky when it asks. One person at a time.")
                        .font(.footnote).foregroundStyle(Theme.inkMuted)
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Theme.surface100)
        .sheet(isPresented: $composing) {
            MessageComposer(body: message) { composing = false }.ignoresSafeArea()
        }
    }
}
