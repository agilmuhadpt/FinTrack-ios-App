import XCTest

/// Shared harness. Every test launches a fresh app with the DEBUG launch arguments that put
/// it in a known state, so nothing depends on state left behind by a previous test.
class FinTrackUITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    /// Launches with the demo ledger and no launch banner (the banner overlays the top of the
    /// screen for its first 12 seconds and would sit on top of anything being tapped).
    /// `resetDemo: false` deliberately preserves whatever is on disk — needed by the
    /// relaunch test, which exists to prove a delete was persisted.
    func launch(tab: String? = nil, extra: [String] = [], resetDemo: Bool = true) {
        // -FTDemo resets the persisted ledger: these tests really do delete rows and the
        // app really does persist that, so without it test N inherits test N-1's damage.
        var args = ["-FTNoBanner", "1"]
        if resetDemo { args += ["-FTDemo", "1"] }
        if let tab { args += ["-FTTab", tab] }
        args += extra
        app.launchArguments = args
        app.launch()
    }

    /// Waits for an element and fails with a useful message rather than a bare timeout.
    @discardableResult
    func require(_ element: XCUIElement,
                 _ what: String,
                 timeout: TimeInterval = 10,
                 file: StaticString = #filePath,
                 line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(element.waitForExistence(timeout: timeout),
                      "expected \(what) to exist", file: file, line: line)
        return element
    }

    func requireGone(_ element: XCUIElement,
                     _ what: String,
                     timeout: TimeInterval = 10,
                     file: StaticString = #filePath,
                     line: UInt = #line) {
        let gone = NSPredicate(format: "exists == false")
        let exp = XCTNSPredicateExpectation(predicate: gone, object: element)
        let result = XCTWaiter().wait(for: [exp], timeout: timeout)
        XCTAssertEqual(result, .completed, "expected \(what) to disappear", file: file, line: line)
    }

    // MARK: - Gesture primitives

    /// A finger-tracked drag: press, move to a point offset from the start, release.
    /// `press(forDuration:thenDragTo:)` is what XCUITest offers for a controlled 1:1 drag —
    /// `swipeLeft()` alone gives no control over distance, which is exactly what these
    /// threshold tests need to vary.
    /// A deliberately SLOW drag: 50 pt/s is 0.05 px/ms, comfortably under the 0.11 px/ms
    /// flick threshold, so only the distance branch of the release rule can fire.
    static let slow = XCUIGestureVelocity(50)
    /// A flick: 800 pt/s is 0.8 px/ms, far over the threshold.
    static let flick = XCUIGestureVelocity(800)

    func drag(_ element: XCUIElement,
              dx: CGFloat,
              dy: CGFloat,
              holdBefore: TimeInterval = 0.05,
              velocity: XCUIGestureVelocity? = nil,
              holdAfter: TimeInterval = 0) {
        let bounds = element.frame
        // Normalised offsets, so the maths is independent of where the element sits.
        let startX = 0.5
        let startY = 0.5
        let endX = startX + dx / bounds.width
        let endY = startY + dy / bounds.height

        let start = element.coordinate(withNormalizedOffset: CGVector(dx: startX, dy: startY))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: endX, dy: endY))

        if let velocity {
            start.press(forDuration: holdBefore,
                        thenDragTo: end,
                        withVelocity: velocity,
                        thenHoldForDuration: holdAfter)
        } else {
            start.press(forDuration: holdBefore, thenDragTo: end)
        }
    }
}
