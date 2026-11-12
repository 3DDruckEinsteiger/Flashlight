import XCTest

#if os(iOS)

/// Drives the real app in the simulator: every control is tapped and its effect checked.
final class ScreenlightUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(reset: Bool = true, extra: [String] = []) {
        var arguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-hintDismissed", "YES"]
        if reset { arguments += ["-uiTestReset", "YES"] }
        app.launchArguments = arguments + extra
        app.launch()
        XCTAssertTrue(element("power").waitForExistence(timeout: 20))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func value(_ identifier: String) -> String {
        element(identifier).value as? String ?? ""
    }

    // MARK: - Light

    func testPowerTogglesTheLight() {
        launch()
        XCTAssertEqual(value("power"), "On")
        XCTAssertEqual(value("surface"), "On")
        element("power").tap()
        XCTAssertEqual(value("power"), "Off")
        XCTAssertEqual(value("surface"), "Off")
        element("power").tap()
        XCTAssertEqual(value("power"), "On")
    }

    func testLightOnlyHidesAndTapRestoresControls() {
        launch()
        element("lightOnly").tap()
        XCTAssertTrue(element("power").waitForNonExistence(timeout: 3))
        element("surface").tap()
        XCTAssertTrue(element("power").waitForExistence(timeout: 3))
    }

    func testFirstLaunchShowsTipsThatCanBeClosed() {
        app.launchArguments = ["-AppleLanguages", "(en)", "-uiTestReset", "YES"]
        app.launch()
        XCTAssertTrue(element("hint.close").waitForExistence(timeout: 20))
        let tips = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS 'Swipe sideways: color'")).firstMatch
        XCTAssertTrue(tips.exists, "the tips mention the swipe gesture")
        element("hint.close").tap()
        XCTAssertTrue(element("hint.close").waitForNonExistence(timeout: 3))
    }

    // MARK: - Colour and brightness

    func testPickingAColorSelectsItsSwatch() {
        launch()
        XCTAssertTrue(element("swatch.#FFFFFF").isSelected)
        element("swatch.#FF0000").tap()
        XCTAssertTrue(element("swatch.#FF0000").isSelected)
        XCTAssertFalse(element("swatch.#FFFFFF").isSelected)
    }

    func testSwipingSidewaysStepsThroughColors() {
        launch()
        // Swipe on the free light above the panel, not on the panel itself.
        drag(fromX: 0.8, y: 0.15, toX: 0.2, y: 0.15)
        XCTAssertTrue(element("swatch.#FFD199").isSelected, "swipe left selects the next preset")
        drag(fromX: 0.2, y: 0.15, toX: 0.8, y: 0.15)
        XCTAssertTrue(element("swatch.#FFFFFF").isSelected, "swipe right goes back")
    }

    func testBrightnessBySliderAndBySwipe() {
        launch()
        XCTAssertEqual(value("brightness"), "100%")
        element("brightness").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let afterTap = percent("brightness")
        XCTAssertTrue((35...65).contains(afterTap), "tapping the middle of the slider gives about half: \(afterTap)")

        drag(fromX: 0.5, y: 0.08, toX: 0.5, y: 0.30)
        let afterSwipeDown = percent("brightness")
        XCTAssertLessThan(afterSwipeDown, afterTap, "swiping down on the light dims it")

        drag(fromX: 0.5, y: 0.30, toX: 0.5, y: 0.10)
        XCTAssertGreaterThan(percent("brightness"), afterSwipeDown, "swiping up makes it brighter")
    }

    func testWhiteToneSliderChangesTheColor() {
        launch()
        element("whiteTone").coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        XCTAssertEqual(value("whiteTone"), "Warm")
        XCTAssertFalse(element("swatch.#FFFFFF").isSelected)
        element("whiteTone").coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(value("whiteTone"), "Cool")
    }

    // MARK: - Modes

    func testEveryModeCanBeSelected() {
        launch()
        element("tab.mode").tap()
        for mode in ["SOS", "Candle", "Disco", "Rainbow", "Gradient", "Normal"] {
            element("mode.\(mode)").tap()
            XCTAssertTrue(element("mode.\(mode)").isSelected, mode)
            XCTAssertEqual(value("power"), "On")
        }
        element("mode.Gradient").tap()
        XCTAssertTrue(app.staticTexts["From"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["To"].exists)
    }

    func testPickingAColorLeavesAnAnimatedMode() {
        launch()
        element("tab.mode").tap()
        element("mode.Rainbow").tap()
        element("tab.color").tap()
        element("swatch.#FF0000").tap()
        element("tab.mode").tap()
        XCTAssertTrue(element("mode.Normal").isSelected)
    }

    func testSelectingAModeTurnsTheLightOn() {
        launch()
        element("power").tap()
        XCTAssertEqual(value("power"), "Off")
        element("tab.mode").tap()
        element("mode.Candle").tap()
        XCTAssertEqual(value("power"), "On")
    }

    // MARK: - Timer

    func testTimerSwitchesTheLightOffAndBrightnessSurvives() {
        launch(extra: ["-uiTestSecondsPerMinute", "8"])
        element("tab.timer").tap()
        element("timer.1").tap()
        XCTAssertTrue(element("timer.stop").waitForExistence(timeout: 2))
        let off = NSPredicate(format: "value == 'Off'")
        expectation(for: off, evaluatedWith: element("power"))
        waitForExpectations(timeout: 30)
        XCTAssertFalse(element("timer.stop").exists)
        element("power").tap()
        XCTAssertEqual(value("power"), "On")
        XCTAssertEqual(value("brightness"), "100%", "the light comes back at the old brightness")
    }

    func testTimerCanBeStoppedAndEndsWhenLightIsSwitchedOff() {
        launch()
        element("tab.timer").tap()
        element("timer.5").tap()
        XCTAssertTrue(element("timer.stop").waitForExistence(timeout: 2))
        element("timer.stop").tap()
        XCTAssertTrue(element("timer.stop").waitForNonExistence(timeout: 2))
        XCTAssertEqual(value("power"), "On")

        element("timer.15").tap()
        XCTAssertTrue(element("timer.stop").waitForExistence(timeout: 2))
        element("power").tap()
        XCTAssertTrue(element("timer.stop").waitForNonExistence(timeout: 2))
    }

    func testTimerHidesControlsThenBringsThemBack() {
        launch(extra: ["-uiTestSecondsPerMinute", "20"])
        element("tab.timer").tap()
        element("timer.1").tap()
        element("lightOnly").tap()
        XCTAssertTrue(element("power").waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("power").waitForExistence(timeout: 40), "controls return when the timer ends")
        XCTAssertEqual(value("power"), "Off")
    }

    // MARK: - Favourites

    func testFavoriteCanBeSavedRemovedAndRestored() {
        launch()
        element("swatch.#0D66FF").tap()
        element("favorite.save").tap()
        let favorite = element("favorite.#0D66FF")
        XCTAssertTrue(favorite.waitForExistence(timeout: 2))
        XCTAssertFalse(element("favorite.save").isEnabled, "the colour is already saved")

        favorite.press(forDuration: 1.2)
        let remove = app.buttons["Remove favorite"]
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        remove.tap()
        XCTAssertTrue(favorite.waitForNonExistence(timeout: 3))

        XCTAssertTrue(element("undo").waitForExistence(timeout: 8), app.debugDescription)
        element("undo").tap()
        XCTAssertTrue(favorite.waitForExistence(timeout: 2))
    }

    // MARK: - Life cycle and layout

    func testSettingsSurviveARestart() {
        launch()
        element("swatch.#FF0000").tap()
        element("tab.mode").tap()
        element("mode.SOS").tap()
        XCUIDevice.shared.press(.home)
        sleep(1)
        app.terminate()

        launch(reset: false)
        XCTAssertTrue(element("mode.SOS").isSelected)
        element("tab.color").tap()
        XCTAssertTrue(element("swatch.#FF0000").isSelected)
    }

    func testBackgroundAndForegroundKeepTheState() {
        launch()
        element("swatch.#26E640").tap()
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(element("power").waitForExistence(timeout: 5))
        XCTAssertEqual(value("power"), "On")
        XCTAssertTrue(element("swatch.#26E640").isSelected)
    }

    func testLandscapeKeepsEverythingReachable() {
        launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        for identifier in ["tab.color", "tab.mode", "tab.timer", "brightness", "lightOnly", "power"] {
            XCTAssertTrue(element(identifier).isHittable || scrollTo(identifier), "\(identifier) in landscape")
        }
        element("power").tap()
        XCTAssertEqual(value("power"), "Off")
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        XCTAssertTrue(element("power").isHittable)
    }

    func testVeryLargeTextKeepsControlsUsable() {
        launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        for identifier in ["tab.color", "tab.mode", "tab.timer"] {
            XCTAssertTrue(element(identifier).isHittable || scrollTo(identifier), identifier)
        }
        XCTAssertTrue(element("power").isHittable || scrollTo("power"))
        element("power").tap()
        XCTAssertEqual(value("power"), "Off")
    }

    func testEveryControlHasAnAccessibilityLabel() {
        launch()
        for tab in ["tab.color", "tab.mode", "tab.timer"] {
            element(tab).tap()
            for button in app.buttons.allElementsBoundByIndex where button.exists {
                XCTAssertFalse(button.label.isEmpty, "button without label on \(tab): \(button.identifier)")
            }
        }
        XCTAssertEqual(element("brightness").label, "Brightness")
        XCTAssertEqual(element("surface").label, "Light")
    }

    func testControlsCannotBeHiddenWhileTheLightIsOff() {
        launch()
        element("power").tap()
        XCTAssertEqual(value("power"), "Off")
        element("lightOnly").tap()
        XCTAssertTrue(element("power").exists, "Light only must not leave a black screen")
        element("surface").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(element("power").exists, "a tap on the dark screen must not hide the controls")
    }

    func testTappingTheSelectedModeTurnsTheLightOn() {
        launch()
        element("power").tap()
        element("tab.mode").tap()
        element("mode.Normal").tap()
        XCTAssertEqual(value("power"), "On")
    }

    func testFavoritesFromVersionOneAreKept() {
        // Version 1.0 stored favourites as JSON with exactly these fields.
        launch(extra: ["-uiTestLegacyFavorites", "YES"])
        XCTAssertTrue(element("favorite.#3399FF").waitForExistence(timeout: 5))
        XCTAssertEqual(element("favorite.#3399FF").label, "Sky")
    }

    func testFavoriteHasASpokenColorName() {
        launch()
        element("swatch.#0D66FF").tap()
        element("favorite.save").tap()
        XCTAssertEqual(element("favorite.#0D66FF").label, "Blue")
    }

    // MARK: - Store preview

    /// Not a test: plays a short tour through the app while the simulator records
    /// the screen for the App Store preview video. Runs only with STORE_DEMO=1.
    func testStorePreviewTour() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_DEMO"] == "1", "only for recording the preview")
        launch(extra: ["-colorRed", "1", "-colorGreen", "0.82", "-colorBlue", "0.6"])
        pause(1.2)
        for swatch in ["#FF0000", "#0D66FF", "#B34DFF"] {
            element("swatch.\(swatch)").tap()
            pause(0.3)
        }
        slide("whiteTone", from: 0.5, to: 0.9)
        slide("whiteTone", from: 0.9, to: 0.1)
        slide("brightness", from: 0.97, to: 0.35)
        slide("brightness", from: 0.35, to: 0.97)
        element("tab.mode").tap()
        element("mode.Candle").tap()
        pause(2.0)
        element("mode.Rainbow").tap()
        pause(2.0)
        element("tab.timer").tap()
        element("timer.15").tap()
        pause(1.0)
        element("lightOnly").tap()
        pause(0.6)
        drag(fromX: 0.5, y: 0.3, toX: 0.5, y: 0.6)
        drag(fromX: 0.5, y: 0.6, toX: 0.5, y: 0.2)
        pause(0.5)
        element("surface").tap()
        pause(2.5)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func slide(_ identifier: String, from: CGFloat, to: CGFloat) {
        let slider = element(identifier)
        let start = slider.coordinate(withNormalizedOffset: CGVector(dx: from, dy: 0.5))
        let end = slider.coordinate(withNormalizedOffset: CGVector(dx: to, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    private func drag(fromX: CGFloat, y fromY: CGFloat, toX: CGFloat, y toY: CGFloat) {
        let surface = element("surface")
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: fromX, dy: fromY))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: toX, dy: toY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func percent(_ identifier: String) -> Int {
        Int(value(identifier).filter(\.isNumber)) ?? -1
    }

    /// Scrolls the panel (used when it does not fit on screen) until the element can be tapped.
    private func scrollTo(_ identifier: String) -> Bool {
        let target = element(identifier)
        for _ in 0..<6 where !target.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        return target.isHittable
    }
}
#endif

#if os(macOS)
/// The Mac version: mouse, keyboard and menu. These tests take over the pointer while they run.
final class ScreenlightMacUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-hintDismissed", "YES", "-uiTestReset", "YES"]
        app.launch()
        XCTAssertTrue(element("power").waitForExistence(timeout: 20))
    }

    override func tearDown() {
        app.terminate()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func value(_ identifier: String) -> String {
        element(identifier).value as? String ?? ""
    }

    func testMouseOperatesEveryPartOfThePanel() {
        XCTAssertEqual(value("power"), "On")
        element("swatch.#FF0000").click()
        XCTAssertTrue(element("swatch.#FF0000").isSelected)
        element("tab.mode").click()
        for mode in ["SOS", "Candle", "Disco", "Rainbow", "Gradient", "Normal"] {
            element("mode.\(mode)").click()
            XCTAssertTrue(element("mode.\(mode)").isSelected, mode)
        }
        element("tab.timer").click()
        element("timer.5").click()
        XCTAssertTrue(element("timer.stop").waitForExistence(timeout: 3))
        element("timer.stop").click()
        XCTAssertTrue(element("timer.stop").waitForNonExistence(timeout: 3))
        element("power").click()
        XCTAssertEqual(value("power"), "Off")
        element("power").click()
        XCTAssertEqual(value("power"), "On")
    }

    func testKeyboardChangesColorBrightnessAndPower() {
        element("surface").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).click()
        XCTAssertTrue(element("power").waitForNonExistence(timeout: 3), "a click on the light hides the controls")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("power").waitForExistence(timeout: 3), "Escape brings the controls back")

        app.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(element("swatch.#FFD199").isSelected, "right arrow selects the next colour")
        app.typeKey(.leftArrow, modifierFlags: [])
        XCTAssertTrue(element("swatch.#FFFFFF").isSelected)

        XCTAssertEqual(value("brightness"), "100%")
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertEqual(value("brightness"), "80%")
        app.typeKey(.upArrow, modifierFlags: [])
        XCTAssertEqual(value("brightness"), "90%")

        app.typeKey(" ", modifierFlags: [])
        XCTAssertEqual(value("power"), "Off")
        app.typeKey(" ", modifierFlags: [])
        XCTAssertEqual(value("power"), "On")
    }

    func testMenuCommands() {
        app.typeKey("l", modifierFlags: .command)
        XCTAssertEqual(value("power"), "Off")
        app.typeKey("l", modifierFlags: .command)
        XCTAssertEqual(value("power"), "On")
        app.typeKey(.downArrow, modifierFlags: .command)
        XCTAssertEqual(value("brightness"), "90%")
        app.typeKey(.rightArrow, modifierFlags: .command)
        XCTAssertTrue(element("swatch.#FFD199").isSelected)
        XCTAssertTrue(app.menuBars.menuBarItems["Light"].exists)
    }

    func testLightOnlyEntersAndLeavesFullScreen() {
        let window = app.windows.firstMatch
        let before = window.frame
        element("lightOnly").click()
        XCTAssertTrue(element("power").waitForNonExistence(timeout: 5))
        sleep(2)
        XCTAssertGreaterThan(window.frame.width, before.width, "the window fills the display")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(element("power").waitForExistence(timeout: 5))
        sleep(2)
        XCTAssertEqual(window.frame.width, before.width, accuracy: 2, "the window returns to its size")
    }
}
#endif
