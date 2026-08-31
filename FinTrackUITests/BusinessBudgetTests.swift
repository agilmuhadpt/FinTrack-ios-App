import XCTest

/// The Studio budget bar, which used to be a hardcoded 48/22/30 inherited from the
/// prototype because the app recorded no business expenses at all.
///
/// The seed is 3,180 / 1,120 / 1,900 of 6,200 = 51/18/31, chosen so it does NOT reproduce
/// the old hardcoded 48/22/30. Even so, a static reading proves little: the real check is
/// recording an expense and watching every share move, which is what these tests do.
final class BusinessBudgetTests: FinTrackUITestCase {

    private func launchBusiness() {
        launch(extra: ["-FTMode", "business"])
        XCTAssertTrue(app.staticTexts["Milestones"].waitForExistence(timeout: 10))
    }

    /// Records a business expense through the real sheet: open, choose a bucket, type an
    /// amount, save.
    private func recordBusinessExpense(bucket: String, amount: String) {
        app.buttons["New entry"].tap()
        require(app.staticTexts["New entry"], "the entry sheet")

        // Opened from Studio mode, so the ledger already defaults to business.
        XCTAssertTrue(app.buttons["Studio"].exists, "the ledger row")
        require(app.buttons[bucket], "the \(bucket) bucket").tap()

        let field = app.textFields.firstMatch
        require(field, "the amount field")
        field.tap()
        field.typeText(amount)

        app.buttons["Save entry"].tap()
        requireGone(app.staticTexts["New entry"], "the sheet after saving")
    }

    /// 3,180 / 1,120 / 1,900 = 51/18/31. Add 3,800 to Growth and the totals become
    /// 3,180 / 4,920 / 1,900 of 10,000 = 32/49/19. Every share moves, including the two
    /// buckets that were not touched — which is only possible if the bar is computed.
    func testRecordingABusinessExpenseMovesEveryShare() {
        launchBusiness()
        XCTAssertTrue(app.staticTexts["51%"].exists, "Ops starts at 51%")
        XCTAssertTrue(app.staticTexts["18%"].exists, "Growth starts at 18%")
        XCTAssertTrue(app.staticTexts["31%"].exists, "Profit starts at 31%")

        // 3,180 / 4,920 / 1,900 of 10,000 = 32/49/19.
        recordBusinessExpense(bucket: "Growth", amount: "3800")

        XCTAssertTrue(app.staticTexts["32%"].waitForExistence(timeout: 5),
                      "Ops share falls to 32% as the denominator grows")
        XCTAssertTrue(app.staticTexts["49%"].exists, "Growth rises to 49%")
        XCTAssertTrue(app.staticTexts["19%"].exists, "Profit share falls to 19%")
        XCTAssertFalse(app.staticTexts["18%"].exists,
                       "the starting split must be gone — the bar is computed, not fixed")
    }

    /// A business expense must not touch the personal 50/30/20 bar. The two bucket sets
    /// are separate ledgers and an expense lands in exactly one.
    func testBusinessExpenseLeavesThePersonalBarUntouched() {
        launchBusiness()
        recordBusinessExpense(bucket: "Ops", amount: "1000")

        app.buttons["Personal"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["52%"].waitForExistence(timeout: 5),
                      "personal Needs stays 52% — 2,600 of 5,000")
        XCTAssertTrue(app.staticTexts["26%"].exists, "personal Wants stays 26%")
        XCTAssertTrue(app.staticTexts["22%"].exists, "personal Savings stays 22%")
    }

    /// And the reverse: a personal expense must not appear in the business bar.
    func testPersonalExpenseLeavesTheBusinessBarUntouched() {
        launch()   // personal mode
        XCTAssertTrue(app.staticTexts["Milestones"].waitForExistence(timeout: 10))

        app.buttons["New entry"].tap()
        require(app.staticTexts["New entry"], "the entry sheet")
        require(app.buttons["Wants"], "the Wants bucket").tap()
        let field = app.textFields.firstMatch
        field.tap()
        field.typeText("5000")
        app.buttons["Save entry"].tap()
        requireGone(app.staticTexts["New entry"], "the sheet after saving")

        app.buttons["Studio"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["51%"].waitForExistence(timeout: 5),
                      "business Ops unchanged at 51%")
        XCTAssertTrue(app.staticTexts["31%"].exists, "business Profit unchanged at 31%")
    }
}
