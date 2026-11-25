import XCTest

final class SettingsConnectionUITests: XCTestCase {
    @MainActor private func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }
    @MainActor private func connection(in app: XCUIApplication) -> XCUIElement {
        let query = NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@",
            "settings.health.connect", "连接 / 检查 Apple 健康")
        let button = app.buttons.matching(query).firstMatch
        for _ in 0..<6 {
            if button.exists && button.isHittable { return button }
            app.swipeUp()
        }
        XCTAssertTrue(button.exists && button.isHittable)
        return button
    }
    @MainActor private func waitForStatus(_ phrase: String, in app: XCUIApplication) {
        let status = app.staticTexts["settings.health.status"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", phrase), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }
    @MainActor func testSettingsWaitingFeedback_TC_PHC_001() {
        let app = launch()
        let button = connection(in: app)
        button.tap()
        waitForStatus("等待系统健康请求", in: app)
        XCTAssertFalse(button.isEnabled)
        XCTAssertTrue(button.label.contains("处理中"))
        XCTAssertFalse(app.buttons["settings.health.refresh"].isEnabled)
        XCTAssertTrue(app.staticTexts["settings.health.status"].isHittable)
    }
    @MainActor func testSettingsReadAndEmptyResult_TC_PHC_006() {
        let app = launch()
        let button = connection(in: app)
        button.tap()
        waitForStatus("等待系统健康请求", in: app)
        app.buttons["fixture.read"].tap()
        waitForStatus("正在读取", in: app)
        app.buttons["fixture.finish"].tap()
        waitForStatus("暂无可读取记录", in: app)
        XCTAssertTrue(button.isEnabled)
        XCTAssertFalse(app.staticTexts["settings.health.status"].label.contains("拒绝"))
    }
    @MainActor func testSettingsFailureFeedback_TC_PHC_006() {
        let app = launch(["--synthetic-authorization-failure"])
        let button = connection(in: app)
        button.tap()
        waitForStatus("无法完成健康读取请求", in: app)
        XCTAssertTrue(button.isEnabled)
        XCTAssertTrue(app.staticTexts["settings.health.status"].isHittable)
    }
    @MainActor func testSettingsDemoCannotConnect_TC_PHC_001() {
        let app = launch(["--synthetic-demo"])
        let button = connection(in: app)
        XCTAssertFalse(button.isEnabled)
        XCTAssertFalse(app.buttons["settings.health.refresh"].isEnabled)
        XCTAssertTrue(app.staticTexts["settings.health.demo"].exists)
    }
}
