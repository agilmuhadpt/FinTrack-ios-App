import XCTest

/// Funding Studio milestones.
///
/// Before this they could not be funded at all: `saveEntry` indexed `msPersonal`
/// unconditionally, so the entry sheet's picker never listed a business goal, and the
/// Home cards were deliberately inert. A business deposit counts toward **Profit**, the
/// business mirror of Savings.
final class BusinessMilestoneTests: FinTrackUITestCase {

    /// Seeded business milestones: Q3 revenue target 9,000/15,000 (60%),
    /// Runway reserve 2,000/8,000 (25%), Invoice collection 550/1,200 (46%).

    func testBusinessMilestoneOpensItsDetailScreen() {
        launch(extra: ["-FTMode", "business"])
        require(app.staticTexts["Runway reserve"], "a business milestone card").tap()

        // The prototype left these inert; they must now reach the funding screen.
        require(app.staticTexts["Add money"], "the milestone detail screen")
        XCTAssertTrue(app.staticTexts["Runway reserve"].exists,
                      "and it must be the business goal, not a personal one at the same index")
    }

    func testDepositMovesTheBusinessGoalNotThePersonalOne() {
        launch(extra: ["-FTMode", "business"])
        require(app.staticTexts["Runway reserve"], "the business milestone").tap()
        require(app.staticTexts["Add money"], "the detail screen")

        // 2,000 -> 3,200 of 8,000 is 25% -> 40%.
        XCTAssertTrue(app.staticTexts["25%"].exists, "starts at 25%")
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("1200")
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["40%"].waitForExistence(timeout: 5),
                      "the business goal advances to 40%")
    }

    /// The footnote has to tell the truth about which bucket the money lands in.
    func testDetailSaysDepositsCountTowardProfit() {
        launch(extra: ["-FTMode", "business"])
        require(app.staticTexts["Runway reserve"], "the business milestone").tap()

        let note = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "count toward")
        ).firstMatch
        require(note, "the deposit footnote")
        XCTAssertTrue(note.label.contains("Profit"),
                      "a business deposit counts toward Profit, not Savings")
    }

    func testPersonalMilestoneStillSaysSavings() {
        launch(extra: ["-FTOverlay", "milestone:0"])
        let note = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "count toward")
        ).firstMatch
        require(note, "the deposit footnote")
        XCTAssertTrue(note.label.contains("Savings"),
                      "personal deposits are unchanged")
    }

    /// A deposit into a business goal is Profit, so it must move the Studio budget
    /// bar — the clearest end-to-end proof the two features are wired together.
    func testBusinessDepositMovesTheStudioBar() {
        launch(extra: ["-FTMode", "business"])
        XCTAssertTrue(app.staticTexts["30%"].waitForExistence(timeout: 10),
                      "Profit starts at 30% of 5,000")

        require(app.staticTexts["Runway reserve"], "the business milestone").tap()
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("2500")
        app.buttons["Add"].tap()
        app.buttons["Back"].tap()

        // Profit 1,500 -> 4,000 of 7,500 = 53%; Ops 2,550 -> 34%; Growth 950 -> 13%.
        XCTAssertTrue(app.staticTexts["53%"].waitForExistence(timeout: 5),
                      "Profit rises to 53% once the deposit lands in the business ledger")
        XCTAssertTrue(app.staticTexts["34%"].exists, "Ops share falls to 34%")
    }

    /// Switching ledger in the entry sheet must not leave a stale index pointing into the
    /// other list — the business and personal arrays are different lengths in general.
    func testEntrySheetSwapsTheMilestoneList() {
        launch(extra: ["-FTOverlay", "entry"])
        require(app.staticTexts["New entry"], "the entry sheet")
        require(app.buttons["Milestone"], "the Milestone kind").tap()

        XCTAssertTrue(app.staticTexts["Emergency fund"].waitForExistence(timeout: 5),
                      "personal goals listed first")

        require(app.buttons["Studio"], "the ledger row").tap()
        XCTAssertTrue(app.staticTexts["Q3 revenue target"].waitForExistence(timeout: 5),
                      "switching ledger swaps the list to business goals")
        XCTAssertFalse(app.staticTexts["Emergency fund"].exists,
                       "and personal goals are no longer offered")
    }
}
