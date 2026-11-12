import Combine
import Foundation
import CoreLocation

/// Phone GPS. Needs no signal and no map data.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?

    /// Called for every new fix. The track recorder listens here.
    var onLocation: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        // Keeping the app alive on a locked screen needs the "Location updates" background mode.
        // Only switch it on when the app is set up for it, because iOS stops the app if it is not.
        if let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String],
           modes.contains("location") {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
    }

    var isDenied: Bool { status == .denied || status == .restricted }
    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }

    func start() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingLocation()
    }

    func stop() { manager.stopUpdatingLocation() }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            self.status = newStatus
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let fixes = locations
        Task { @MainActor in
            for fix in fixes {
                self.location = fix
                self.onLocation?(fix)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A failed fix (for example in a canyon) is normal. The next fix replaces it.
    }
}
