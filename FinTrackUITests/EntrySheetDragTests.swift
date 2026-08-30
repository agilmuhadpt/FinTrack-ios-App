import XCTest

/// Drag-to-dismiss on the New Entry sheet, ported from the prototype's `sheetDragStart`
/// (FinTrack.dc.html:801-830):
///
///     dismiss when  dy > 140  OR  (dy > 30 AND velocity > 0.11 px/ms)
///     downward tracks 1:1, upward is damped to 0.15x, otherwise it springs back
///
/// The gesture belongs to the grabber only, not the whole sheet.
final class EntrySheetDragTests: FinTrackUITestCase {

    /// The sheet's own title. An identifier on the sheet CONTAINER is not usable here:
    /// SwiftUI propagates `.accessibilityIdentifier` to every descendant and overwrites
    /// theirs, which clobbered the grabber's own identifier. So presence is detected via
    /// the title text instead, and only the grabber carries an identifier.
    private var sheet: XCUIElement { app.staticTexts["New entry"] }

    private var grabber: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ft.entrySheet.grabber").firstMatch
    }

    private func launchSheet() {
        launch(extra: ["-FTOverlay", "entry"])
        require(sheet, "the entry sheet")
        require(grabber, "the sheet grabber")
        // Let the 350ms present animation finish before dragging.
        Thread.sleep(forTimeInterval: 0.6)
    }

    // MARK: - Distance threshold

    func testDragPastThresholdDismissesSheet() {
        launchSheet()

        drag(grabber, dx: 0, dy: 260)   // well past dy > 140

        requireGone(sheet, "the sheet after a long downward drag")
    }

    func testDragShortOfThresholdSpringsBack() {
        launchSheet()

        // 80pt down: past the 30pt flick distance but short of 140, and slow enough
        // (0.05 px/ms) that the velocity branch cannot fire.
        drag(grabber, dx: 0, dy: 80, velocity: Self.slow)

        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(sheet.exists, "a drag short of 140pt must spring back, not dismiss")
        XCTAssertTrue(app.staticTexts["New entry"].exists, "the sheet must still be usable")
    }

    // MARK: - Velocity threshold

    func testFastFlickDownDismissesSheet() {
        launchSheet()

        // Short but fast: dy > 30 with velocity well over 110 pt/s.
        drag(grabber, dx: 0, dy: 60, holdBefore: 0, velocity: Self.flick)

        requireGone(sheet, "the sheet after a downward flick")
    }

    // MARK: - Upward resistance

    func testUpwardDragIsResistedAndDoesNotDismiss() {
        launchSheet()

        drag(grabber, dx: 0, dy: -120, velocity: Self.slow)

        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(sheet.exists, "dragging up must never dismiss the sheet")
    }

    // MARK: - The gesture belongs to the grabber

    /// The prototype binds the drag to the grabber alone; dragging the sheet body should
    /// not dismiss it. The amount field lives well below the grabber.
    func testDraggingSheetBodyDoesNotDismiss() {
        launchSheet()
        let saveButton = app.buttons["Save entry"]
        require(saveButton, "the Save entry button")

        drag(saveButton, dx: 0, dy: 200, velocity: Self.slow)

        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(sheet.exists, "only the grabber carries drag-to-dismiss")
    }

    // MARK: - Dismissal routes that are not the drag

    func testTappingScrimDismissesSheet() {
        launchSheet()

        // The scrim is the area above the sheet; tap near the top of the screen.
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        top.tap()

        requireGone(sheet, "the sheet after tapping the scrim")
    }
}
