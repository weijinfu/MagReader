import XCTest

@MainActor
final class MagReaderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchSeededApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestSeedData"]
        app.launch()
        return app
    }

    func testLaunchShowsArticlesEmptyStateOrList() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.tabBars.buttons["Articles"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["BBC Learning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tech Review"].exists)
        XCTAssertTrue(app.staticTexts["Reader habits improve vocabulary"].exists)
        XCTAssertTrue(app.staticTexts["Local-first apps keep study data private"].exists)
    }

    func testArticleListOpensArticleDetail() throws {
        let app = launchSeededApp()

        XCTAssertTrue(app.staticTexts["Reader habits improve vocabulary"].waitForExistence(timeout: 5))
        app.staticTexts["Reader habits improve vocabulary"].tap()
        XCTAssertTrue(app.navigationBars["BBC Learning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
    }

    func testSavedAndReviewTabsShowSeededItems() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Context"].waitForExistence(timeout: 5))
        app.staticTexts["Context"].tap()
        XCTAssertTrue(app.navigationBars["Word Detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["语境；上下文"].exists)
        XCTAssertTrue(app.buttons["Show More Meanings"].waitForExistence(timeout: 5))
        app.buttons["Show More Meanings"].tap()
        XCTAssertTrue(app.staticTexts["所选单词前后的、帮助解释其含义的词语。"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Saved"].waitForExistence(timeout: 5))

        app.buttons["Sentences"].tap()
        XCTAssertTrue(app.staticTexts["Daily reading helps learners notice vocabulary in context."].waitForExistence(timeout: 5))
        app.staticTexts["Daily reading helps learners notice vocabulary in context."].tap()
        XCTAssertTrue(app.navigationBars["Sentence Detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["日常阅读帮助学习者在语境中注意词汇。"].exists)
        app.buttons["Done"].tap()

        app.tabBars.buttons["Review"].tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Context"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Reveal"].exists)
        app.buttons["mastered"].firstMatch.tap()
        XCTAssertTrue(app.alerts["Mark as mastered?"].waitForExistence(timeout: 5))
        app.alerts["Mark as mastered?"].buttons["Delete"].tap()
        XCTAssertFalse(app.staticTexts["Context"].waitForExistence(timeout: 2))
    }

    func testSettingsTabIsReachable() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reading"].exists)
        XCTAssertTrue(app.staticTexts["Background"].exists)
        XCTAssertTrue(app.staticTexts["Translation"].exists)
    }

    func testFeedsTabShowsSeededFeeds() throws {
        let app = launchSeededApp()

        app.tabBars.buttons["Feeds"].tap()
        XCTAssertTrue(app.navigationBars["Feeds"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["BBC Learning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tech Review"].exists)
    }
}
