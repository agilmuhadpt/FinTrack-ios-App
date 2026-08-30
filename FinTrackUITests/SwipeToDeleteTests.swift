import XCTest

/// Activity swipe-to-delete, ported from the prototype's `rowDragStart`
/// (FinTrack.dc.html:766-800). The release rule being verified is:
///
///     delete when  dx < -80  OR  (dx < -24 AND velocity < -0.11 px/ms)
///
/// Everything else springs back over 250ms. These are the only tests that actually
/// exercise the gesture — a green build says nothing about it.
final class SwipeToDeleteTests: FinTrackUITestCase {

    /// Demo ledger (AppData.demo): Today = Groceries, Studio payout;
    /// Yesterday = Coffee, Adam repayment, Fuel.
    private func row(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ft.row.\(title)").firstMatch
    }

    private func launchActivity() {
        launch(tab: "activity")
        require(row("Groceries"), "the Groceries row")
    }

    // MARK: - Distance threshold

    func testSwipePastDistanceThresholdDeletesRow() {
        launchActivity()
        let groceries = row("Groceries")
        let survivor = row("Studio payout")
        XCTAssertTrue(survivor.exists, "sibling row should be present before the swipe")

        // Well past the -80pt release threshold.
        drag(groceries, dx: -160, dy: 0)

        requireGone(groceries, "the swiped row")
        XCTAssertTrue(survivor.exists, "swiping one row must not remove its neighbour")
    }

    func testSwipeShortOfThresholdSpringsBackAndKeepsRow() {
        launchActivity()
        let coffee = row("Coffee")

        // -50pt: past the -24pt flick distance but short of -80, and dragged slowly
        // enough (0.05 px/ms) that the velocity branch cannot fire either.
        drag(coffee, dx: -50, dy: 0, velocity: Self.slow)

        // Give the 250ms spring-back time to settle, then assert nothing was deleted.
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(coffee.exists, "a swipe short of -80pt must spring back, not delete")
        XCTAssertTrue(row("Fuel").exists, "unrelated rows must be untouched")
    }

    func testTinySwipeIsIgnored() {
        launchActivity()
        let fuel = row("Fuel")

        drag(fuel, dx: -12, dy: 0, velocity: Self.slow)

        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(fuel.exists, "a 12pt drag is below every threshold")
    }

    // MARK: - Velocity threshold

    /// The prototype deletes on a leftward flick even when the distance is small:
    /// `dx < -24 && velocity < -0.11 px/ms`. 0.11 px/ms is 110 pt/s, so this drag is
    /// deliberately short but fast.
    func testFastFlickDeletesRowBelowDistanceThreshold() {
        launchActivity()
        let niyas = row("Adam repayment")

        drag(niyas, dx: -60, dy: 0, holdBefore: 0, velocity: Self.flick)

        requireGone(niyas, "the flicked row")
    }

    // MARK: - Scrolling must survive

    func testVerticalPanDoesNotDeleteRow() {
        launchActivity()
        let groceries = row("Groceries")

        // A mostly-vertical drag must reach the ScrollView, not the row's delete gesture.
        drag(groceries, dx: -6, dy: -220)

        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(groceries.exists, "a vertical pan must scroll, never delete")
    }

    // MARK: - The mutation is real, not just visual

    func testDeletionSurvivesRelaunch() {
        launchActivity()
        let groceries = row("Groceries")
        drag(groceries, dx: -160, dy: 0)
        requireGone(groceries, "the swiped row")

        // Relaunching proves the swipe mutated the store and the store persisted, rather
        // than the row merely being animated off screen.
        app.terminate()
        // Deliberately NOT resetting to demo — the point is to read back what was persisted.
        launch(tab: "activity", resetDemo: false)
        require(row("Coffee"), "an untouched row after relaunch")
        XCTAssertFalse(row("Groceries").exists,
                       "the delete must have been written to disk, not just animated away")
    }

    /// Deleting every row in a day group must remove the group header too
    /// (`days.filter(d => d.items.length)`), and then the empty state appears.
    func testDeletingBothTodayRowsRemovesTheGroup() {
        launchActivity()
        XCTAssertTrue(app.staticTexts["TODAY"].exists, "the TODAY group header")

        drag(row("Groceries"), dx: -160, dy: 0)
        requireGone(row("Groceries"), "first Today row")

        drag(row("Studio payout"), dx: -160, dy: 0)
        requireGone(row("Studio payout"), "second Today row")

        requireGone(app.staticTexts["TODAY"], "the emptied TODAY group header")
        XCTAssertTrue(app.staticTexts["YESTERDAY"].exists, "the other group must remain")
    }
}
