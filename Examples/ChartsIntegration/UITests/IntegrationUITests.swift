import XCTest

final class IntegrationUITests: XCTestCase {
    @MainActor private func verify(_ language: String) {
        let app = XCUIApplication(bundleIdentifier: "com.hoymiles.audit." + language + "Host")
        app.launch()
        let status = app.staticTexts["integration-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertTrue(status.label.hasPrefix("PASS"), status.label)
        XCTAssertTrue(status.label.contains("released=30/30"), status.label)
        XCTAssertTrue(status.label.contains("neutral=true"), status.label)
        // A real gesture verifies that a newly imported chart renders and returns the updated model.
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 190, dy: 290)).tap()
        let hit = app.staticTexts["integration-hit"]
        let matching = NSPredicate(format: "label == %@", "hit:power:500")
        expectation(for: matching, evaluatedWith: hit)
        waitForExpectations(timeout: 5)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = language + "-public-import"
        image.lifetime = .keepAlways; add(image)
        app.terminate()
    }
    @MainActor func testSwiftPublicImport() { verify("Swift") }
    @MainActor func testObjectiveCPublicImport() { verify("OC") }
}
