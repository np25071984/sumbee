import XCTest

/// Plays a whole session the way a child would, through the keypad, and saves a screenshot of each
/// state. Set SCREENSHOT_DIR (TEST_RUNNER_SCREENSHOT_DIR from xcodebuild) to get them as PNG files;
/// they are always attached to the test result too.
final class SessionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Seed 16 opens with 7 × 9, 6 × 6 and 10 + 4 for "Jenny", + and ×, numbers up to 20: good
        // cards for the store screenshots. Any seed works for the test itself.
        app.launchArguments = ["-uiTesting", "-seed", "16"]
        // ORIENTATION=landscape (TEST_RUNNER_ORIENTATION from xcodebuild) plays the session in
        // landscape, the shortest window an iPad gives the app. iPhone stays portrait regardless.
        let landscape = ProcessInfo.processInfo.environment["ORIENTATION"] == "landscape"
        XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        // LANGUAGE=es (TEST_RUNNER_LANGUAGE from xcodebuild) plays the same session in Spanish.
        if language == "es" { app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_MX"] }
        app.launch()
    }

    func testAFullSession() {
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 5))
        let name = app.textFields["name"]
        name.tap()
        // On a freshly booted simulator, typing before the keyboard is up drops letters.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        // Even then it sometimes drops one, so clear and retype until the name is whole.
        for _ in 0..<3 where name.value as? String != "Jenny" {
            let typed = (name.value as? String).map { $0 == t("Your name") ? 0 : $0.count } ?? 0
            name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed) + "Jenny")
        }
        XCTAssertEqual(name.value as? String, "Jenny")
        name.typeText("\n")
        app.buttons["op.TIMES"].tap()
        XCTAssertTrue(app.buttons["op.TIMES"].isSelected)
        Thread.sleep(forTimeInterval: 0.5) // let the tile finish changing colour
        screenshot("01-setup")

        app.buttons["start"].tap()
        XCTAssertEqual(text("progress"), "1 / 25")
        XCTAssertTrue(app.staticTexts[t("Ready, Jenny?")].exists)
        screenshot("02-first-card")

        // Card 1: right first time.
        answer(correct())
        XCTAssertTrue(app.staticTexts[t("Correct!")].exists)
        waitFor("progress", "2 / 25")

        // Card 2: wrong, nudged, then wrong again and the answer is shown.
        let card2 = correct()
        answer(wrong(card2))
        XCTAssertTrue(app.staticTexts[t("Are you sure? Check again.")].exists)
        XCTAssertEqual(text("progress"), "2 / 25")
        screenshot("03-nudge")
        app.buttons["key.submit"].tap()
        XCTAssertTrue(app.staticTexts[t("The answer is %@", "\(card2)")].exists)
        screenshot("04-reveal")
        waitFor("progress", "3 / 25")
        screenshot("05-card")

        // The rest: right first time.
        for n in 3...25 {
            answer(correct())
            if n < 25 { waitFor("progress", "\(n + 1) / 25") }
        }
        XCTAssertTrue(app.buttons["playAgain"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[t("Jenny's score:")].exists)
        XCTAssertEqual(app.staticTexts["score"].label, t("24 out of 25"))
        screenshot("06-results")

        // Play again goes straight to a new deck; ✕ twice leaves to Setup, which kept the settings.
        app.buttons["playAgain"].tap()
        XCTAssertEqual(text("progress"), "1 / 25")
        app.buttons["exit"].tap()
        XCTAssertTrue(app.staticTexts[t("Tap ✕ again to stop")].exists)
        screenshot("07-exit-hint")
        app.buttons["exit"].tap()
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 2))
        XCTAssertEqual(name.value as? String, "Jenny")
        XCTAssertTrue(app.buttons["op.TIMES"].isSelected)
    }

    func testOneTapOnExitDoesNotLeave() {
        app.buttons["start"].tap()
        app.buttons["exit"].tap()
        XCTAssertTrue(app.staticTexts[t("Tap ✕ again to stop")].exists)
        // The hint goes after 2 s, and the next tap only arms the exit again.
        XCTAssertTrue(app.staticTexts[t("Tap ✕ again to stop")].waitForNonExistence(timeout: 4))
        app.buttons["exit"].tap()
        XCTAssertTrue(app.otherElements["problem"].exists)
    }

    // MARK: Helpers

    private func text(_ id: String) -> String {
        app.staticTexts[id].label
    }

    private func waitFor(_ id: String, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let match = NSPredicate(format: "label == %@", label)
        let found = XCTNSPredicateExpectation(predicate: match, object: app.staticTexts[id])
        XCTAssertEqual(XCTWaiter.wait(for: [found], timeout: 5), .completed, "\(id) never showed \(label)", file: file, line: line)
    }

    /// The answer to the card on screen, worked out from its label ("12 ÷ 4").
    private func correct() -> Int {
        let parts = app.otherElements["problem"].label.split(separator: " ")
        let a = Int(parts[0])!, b = Int(parts[2])!
        switch parts[1] {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return a / b
        default: XCTFail("unknown operation in \(parts)"); return 0
        }
    }

    private func wrong(_ answer: Int) -> Int { answer == 0 ? 1 : answer - 1 }

    private func answer(_ n: Int) {
        for ch in String(n) { app.buttons["key.\(ch)"].tap() }
        app.buttons["key.submit"].tap()
    }

    private var language: String? { ProcessInfo.processInfo.environment["LANGUAGE"] }

    /// The text the app shows for `english` in the language under test (Localizable.xcstrings).
    private func t(_ english: String, _ arg: String = "") -> String {
        let spanish = [
            "Your name": "Tu nombre",
            "Ready, Jenny?": "¡Vamos, Jenny!",
            "Correct!": "¡Correcto!",
            "Are you sure? Check again.": "¿Lo revisas otra vez?",
            "The answer is %@": "La respuesta es %@",
            "Jenny's score:": "Puntos de Jenny:",
            "24 out of 25": "24 de 25",
            "Tap ✕ again to stop": "Toca ✕ otra vez para salir",
        ]
        let text = language == "es" ? spanish[english] ?? english : english
        return text.replacingOccurrences(of: "%@", with: arg)
    }

    private func screenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
