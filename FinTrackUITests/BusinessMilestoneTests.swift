import XCTest

/// Funding Studio milestones.
///
/// Before this they could not be funded at all: `saveEntry` indexed `msPersonal`
/// unconditionally, so the entry sheet's picker never listed a business goal, and the
/// Home cards were deliberately inert. A business deposit counts toward **Profit**, the
/// business mirror of Savings.
final class BusinessMilestoneTests: FinTrackUITestCase {

    /// Seeded business milestones: Q3 revenue target 18,400/30,000 (61%),
    /// Runway reserve 5,000/15,000 (33%), Invoice collection 1,450/3,000 (48%).

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

        // 5,000 -> 10,000 of 15,000 is 33% -> 67%.
        XCTAssertTrue(app.staticTexts["33%"].exists, "starts at 33%")
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("5000")
        app.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["67%"].waitForExistence(timeout: 5),
                      "the business goal advances to 67%")
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
                      "Profit starts at 30% of 6,650")

        require(app.staticTexts["Runway reserve"], "the business milestone").tap()
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("3350")
        app.buttons["Add"].tap()
        app.buttons["Back"].tap()

        // Profit 2,000 -> 5,350 of 10,000 = 54%; Ops 3,200 -> 32%; Growth 1,450 -> 15%.
        XCTAssertTrue(app.staticTexts["54%"].waitForExistence(timeout: 5),
                      "Profit rises to 54% once the deposit lands in the business ledger")
        XCTAssertTrue(app.staticTexts["32%"].exists, "Ops share falls to 32%")
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
