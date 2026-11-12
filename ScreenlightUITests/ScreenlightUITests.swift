import XCTest

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
        XCTAssertTrue(app.staticTexts["Swipe sideways: color"].exists)
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
        element("surface").swipeLeft()
        XCTAssertTrue(element("swatch.#FFD199").isSelected, "swipe left selects the next preset")
        element("surface").swipeRight()
        XCTAssertTrue(element("swatch.#FFFFFF").isSelected, "swipe right goes back")
    }

    func testBrightnessBySliderAndBySwipe() {
        launch()
        XCTAssertEqual(value("brightness"), "100%")
        element("brightness").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let afterTap = value("brightness")
        XCTAssertNotEqual(afterTap, "100%", "tapping the middle of the slider dims the light")

        let surface = element("surface")
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.10))
        let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertNotEqual(value("brightness"), afterTap, "swiping down on the light dims it further")
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
        launch(extra: ["-uiTestSecondsPerMinute", "4"])
        element("tab.timer").tap()
        element("timer.1").tap()
        XCTAssertTrue(element("timer.stop").waitForExistence(timeout: 2))
        let off = NSPredicate(format: "value == 'Off'")
        expectation(for: off, evaluatedWith: element("power"))
        waitForExpectations(timeout: 10)
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
        launch(extra: ["-uiTestSecondsPerMinute", "4"])
        element("tab.timer").tap()
        element("timer.1").tap()
        element("lightOnly").tap()
        XCTAssertTrue(element("power").waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("power").waitForExistence(timeout: 10), "controls return when the timer ends")
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

        XCTAssertTrue(element("undo").waitForExistence(timeout: 2))
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
        XCTAssertTrue(element("power").isHittable || scrollTo("power"))
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

    /// Scrolls the panel (used when it does not fit on screen) until the element can be tapped.
    private func scrollTo(_ identifier: String) -> Bool {
        let target = element(identifier)
        for _ in 0..<6 where !target.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        return target.isHittable
    }
}
