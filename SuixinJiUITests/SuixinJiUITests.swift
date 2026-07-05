import XCTest

/// End-to-end P0 flows driven through the UI. The app is launched with `-uitest`
/// so it uses a fresh in-memory store each run (see SuixinJiApp).
final class SuixinJiUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Belt-and-suspenders against a stray system notification banner that
        // slides over the app mid-test (the app also clears notifications under
        // -uitest). Swipe any banner away so it can't block a tap.
        addUIInterruptionMonitor(withDescription: "Dismiss notification banners") { element in
            if element.identifier == "NotificationShortLookView" {
                element.swipeUp()
                return true
            }
            return false
        }
        app = XCUIApplication()
        // -uitest → fresh in-memory store; -uitest-dictate → the 转文字 button
        // injects a canned phrase through the real caret/insert path (no recognizer).
        app.launchArguments = ["-uitest", "-uitest-dictate"]
        app.launch()
    }

    // Empty state (Brief §5): guidance line + the ➕ button are present.
    func testEmptyStateShown() {
        XCTAssertTrue(app.staticTexts["记录今天的第一条心情吧"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["fab.add"].exists)
    }

    // Save is disabled while the entry is empty (Brief §5 / F1).
    func testSaveDisabledWhenEmpty() {
        app.buttons["fab.add"].tap()
        let save = app.buttons["editor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "保存 must be greyed out when the entry is empty")
    }

    // F1 create: ➕ → type → 保存 → new card appears, empty state gone.
    func testCreateTextEntryAppearsInTimeline() {
        let marker = "UI自动化测试内容"
        app.buttons["fab.add"].tap()

        let editor = app.textViews["editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(marker)

        let save = app.buttons["editor.save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["记录今天的第一条心情吧"].exists)
    }

    // Cancel with unsaved changes → discard confirmation → nothing saved.
    func testCancelWithChangesAsksToDiscard() {
        app.buttons["fab.add"].tap()
        let editor = app.textViews["editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("临时内容")

        app.buttons["editor.cancel"].tap()
        // confirmationDialog with the discard prompt.
        let discard = app.buttons["放弃修改"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()

        XCTAssertTrue(app.staticTexts["记录今天的第一条心情吧"].waitForExistence(timeout: 5),
                      "discarded entry must not appear")
    }

    // F6 detail + delete with two-step confirmation (PRD §6).
    func testOpenDetailAndDeleteEntry() {
        let marker = "待删除的日记"
        // create one
        app.buttons["fab.add"].tap()
        let editor = app.textViews["editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(marker)
        app.buttons["editor.save"].tap()

        // open detail
        let card = app.staticTexts[marker]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        // ··· → 删除 → confirm
        app.buttons["detail.menu"].tap()
        app.buttons["删除"].tap()
        let confirm = app.alerts.buttons["删除"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        // back to empty timeline
        XCTAssertTrue(app.staticTexts["记录今天的第一条心情吧"].waitForExistence(timeout: 5))
    }

    // ④ Settings: the mandatory data-storage footer must be present.
    func testSettingsShowsDataFooter() {
        app.buttons["nav.settings"].tap()
        let footer = app.staticTexts["日记仅保存在本机，删除 App 将丢失全部数据。"]
        // The footer sits at the bottom of the (now longer) settings list; scroll
        // to it if it isn't on the first screen.
        if !footer.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(footer.waitForExistence(timeout: 5))
    }

    // 外观: appearance controls (accent swatches + font-size picker) are present
    // and a swatch is tappable (evolution).
    func testAppearanceControls() {
        app.buttons["nav.settings"].tap()
        XCTAssertTrue(app.buttons["accent.orange"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["accent.indigo"].exists)
        app.buttons["accent.indigo"].tap() // switch theme color
        XCTAssertTrue(app.segmentedControls.firstMatch.exists, "字号 segmented picker present")
    }

    // Backup: Settings surfaces the export/import entries (evolution).
    func testSettingsShowsBackupRows() {
        app.buttons["nav.settings"].tap()
        XCTAssertTrue(app.buttons["settings.export"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.import"].exists)
    }

    // Helper: create a text entry with the given marker.
    private func createEntry(_ marker: String) {
        app.buttons["fab.add"].tap()
        let editor = app.textViews["editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(marker)
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.staticTexts[marker].waitForExistence(timeout: 5))
    }

    // 回顾: the "这一天" banner appears when a same-date past-year entry exists,
    // and opens that memory. Relaunched with a seed since the store is in-memory.
    func testOnThisDayMemoriesBanner() {
        app.terminate()
        app.launchArguments = ["-uitest", "-uitest-seed-memory"]
        app.launch()

        let banner = app.buttons["home.memories"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        banner.tap()
        XCTAssertTrue(app.navigationBars["这一天"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["去年今天的回忆"].waitForExistence(timeout: 5))
    }

    // Insights screen opens and shows the stat tiles after there's data.
    func testStatisticsOpens() {
        createEntry("统计用的一条日记")
        app.buttons["nav.stats"].tap()
        XCTAssertTrue(app.navigationBars["统计"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["累计日记"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["连续记录"].exists)
        app.buttons["完成"].tap()
    }

    // F9 calendar opens from the timeline.
    func testCalendarOpens() {
        app.buttons["nav.calendar"].tap()
        XCTAssertTrue(app.navigationBars["日历"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
    }

    // F2: placing the caret in the middle and dictating inserts THERE, not at the
    // end. The caret is moved with arrow keys (deterministic), then the 转文字
    // button injects "语音" at that caret via the real anchor/insert path.
    func testDictationInsertsAtCaret() throws {
        app.buttons["fab.add"].tap()
        let editor = app.textViews["editor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("前面后面")

        // Move the caret left past "后面" → it now sits between "前面" and "后面".
        editor.typeText(XCUIKeyboardKey.leftArrow.rawValue)
        editor.typeText(XCUIKeyboardKey.leftArrow.rawValue)

        // Arrow-key caret movement only takes effect with a connected hardware
        // keyboard; without one the arrows are inserted as literal text. In that
        // case the caret can't be positioned, so skip (the at-caret insert path is
        // device-verified) rather than assert against a caret we couldn't move.
        try XCTSkipUnless(editor.value as? String == "前面后面",
                          "需连接硬件键盘用方向键移动光标；当前环境未生效，跳过光标插入断言。")

        app.buttons["editor.transcribe"].tap()

        XCTAssertEqual(editor.value as? String, "前面语音后面",
                       "dictated text must land at the caret, not appended at the end")
    }

    // F8 keyword search filters the timeline.
    func testSearchFiltersTimeline() {
        createEntry("海边散步很惬意")
        createEntry("加班到很晚")

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("海边")

        XCTAssertTrue(app.staticTexts["海边散步很惬意"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["加班到很晚"].exists)
    }
}
