import XCTest

/// The optional milestone target date and the one number it earns: what finishing on
/// time costs per month.
///
/// The pace ARITHMETIC is covered separately and exhaustively; what these tests guard is
/// the promise that made the feature acceptable — **a milestone with no date renders
/// exactly as it did before**. That is a fidelity guarantee against a prototype the spec
/// declared final, and it is easy to break by accident.
final class MilestonePaceTests: FinTrackUITestCase {

    /// Matches "SAR 292/mo to finish by Aug 2027" without pinning the date, which moves
    /// with the clock (the seeded dates are relative to today).
    private var paceLines: XCUIElementQuery {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "/mo to finish by"))
    }

    // MARK: - The fidelity guarantee

    func testHomeShowsNoPaceLineWhenNoDateIsSet() {
        launch(tab: "home")
        XCTAssertTrue(app.staticTexts["Milestones"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Emergency fund"].exists, "seeded milestone should be visible")

        XCTAssertEqual(paceLines.count, 0,
                       "an undated milestone must render exactly as the prototype does")
    }

    func testDetailOffersToSetADateWhenNoneIsSet() {
        launch(extra: ["-FTOverlay", "milestone:0"])
        require(app.staticTexts["Target date"], "the Target date section")
        XCTAssertTrue(app.buttons["Set a target date"].exists,
                      "an undated milestone offers to set one")
        XCTAssertFalse(app.staticTexts["Finish by"].exists,
                       "and shows no deadline row until it has a date")
    }

    // MARK: - With a date set

    func testHomeShowsPaceLineForDatedMilestones() {
        launch(tab: "home", extra: ["-FTMilestoneDates", "1"])
        XCTAssertTrue(app.staticTexts["Emergency fund"].waitForExistence(timeout: 10))

        // Two of the three seeded dates are in the future; the third is overdue and
        // renders its own copy instead.
        XCTAssertGreaterThanOrEqual(paceLines.count, 1,
                                    "a dated milestone shows what it costs per month")
    }

    func testDetailShowsRequiredMonthlyContribution() {
        launch(extra: ["-FTMilestoneDates", "1", "-FTOverlay", "milestone:0"])
        require(app.staticTexts["Finish by"], "the deadline row")

        let sentence = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "per month over")
        ).firstMatch
        XCTAssertTrue(sentence.waitForExistence(timeout: 5),
                      "the detail screen states the monthly figure in full")
        XCTAssertTrue(app.buttons["Remove date"].exists, "and offers to clear the date")
    }

    /// A date in the past with money still owing is reported plainly, never as a guess
    /// about whether the user is "on track" — there is no contribution history to judge
    /// that from.
    func testOverdueMilestoneSaysSoWithTheAmountOutstanding() {
        launch(extra: ["-FTMilestoneDates", "1", "-FTOverlay", "milestone:2"])
        require(app.staticTexts["Target date"], "the Target date section")

        let overdue = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Overdue by")
        ).firstMatch
        XCTAssertTrue(overdue.waitForExistence(timeout: 5), "an overdue goal says so")
        XCTAssertTrue(overdue.label.contains("still to save"),
                      "and states what is still outstanding, not a pace verdict")
    }

    // MARK: - Clearing the date returns the goal to open-ended

    func testRemovingTheDateRestoresTheUndatedLayout() {
        launch(extra: ["-FTMilestoneDates", "1", "-FTOverlay", "milestone:0"])
        require(app.buttons["Remove date"], "the Remove date button")

        app.buttons["Remove date"].tap()

        XCTAssertTrue(app.buttons["Set a target date"].waitForExistence(timeout: 5),
                      "clearing the date must return the goal to open-ended")
        XCTAssertFalse(app.staticTexts["Finish by"].exists)
    }
}
