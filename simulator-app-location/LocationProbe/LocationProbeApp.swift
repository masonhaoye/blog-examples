import CoreLocation
import SwiftUI
import os

@main
struct LocationProbeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var probe = LocationProbe()

    var body: some View {
        VStack(spacing: 12) {
            Text("LocationProbe")
                .font(.headline)
            Text(probe.coordinate)
                .font(.title2.monospacedDigit())
                .accessibilityIdentifier("probe.coordinate")
            Text(probe.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("probe.detail")
        }
        .padding()
        .task { await probe.start() }
    }
}

/// Shows the latest location the app receives, and when the first one arrived.
@MainActor
@Observable
final class LocationProbe {
    private(set) var coordinate = "No location yet"
    private(set) var detail = "Waiting for a location"

    private let manager = CLLocationManager()
    private let launchedAt = Date()
    private let logger = Logger(subsystem: "com.example.LocationProbe", category: "location")
    private var firstFixAfter: TimeInterval?

    func start() async {
        manager.requestWhenInUseAuthorization()
        logger.log("Launched; waiting for location updates")
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                guard let location = update.location else { continue }
                let seconds = Date().timeIntervalSince(launchedAt)
                let text = String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
                if firstFixAfter == nil {
                    firstFixAfter = seconds
                }
                coordinate = text
                detail = String(format: "First location %.1f s after launch", firstFixAfter ?? seconds)
                logger.log("Location \(text, privacy: .public) at \(seconds, format: .fixed(precision: 1), privacy: .public) s")
            }
        } catch {
            logger.error("Location updates ended: \(error.localizedDescription, privacy: .public)")
        }
    }
}
