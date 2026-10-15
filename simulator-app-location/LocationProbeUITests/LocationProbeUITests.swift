import XCTest

final class LocationProbeUITests: XCTestCase {
    /// Records what the app shows 10 seconds after launch. It reports rather than judges, so the same
    /// test can show which location reached the app under different settings.
    @MainActor
    func testRecordsTheLocationSeenAfterLaunch() {
        let app = XCUIApplication()
        app.launch()

        let coordinate = app.staticTexts["probe.coordinate"]
        XCTAssertTrue(coordinate.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 10)

        print("PROBE coordinate: \(coordinate.label)")
        print("PROBE detail: \(app.staticTexts["probe.detail"].label)")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
