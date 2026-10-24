import XCTest

final class PhoneCareUITests: XCTestCase {
    @MainActor private func launch(_ arguments: [String] = [], fixtureDate: Date = Date()) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment["PHONE_CARE_FIXTURE_NOW"] = String(fixtureDate.timeIntervalSince1970)
        app.launch()
        return app
    }

    @MainActor private func card(_ kind: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.buttons["care.\(kind)"]
        for _ in 0..<10 {
            if element.exists && element.isHittable { return element }
            app.swipeUp()
        }
        return element
    }

    @MainActor private func find(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        for _ in 0..<8 {
            if element.exists && element.isHittable { return element }
            app.swipeUp()
        }
        return element
    }

    @MainActor func testScorelessCards_TC_PTC_002_006() {
        let app = launch()
        let energy = card("energy", in: app)
        XCTAssertTrue(energy.exists, app.debugDescription)
        XCTAssertTrue(energy.label.contains("身体电量估算"))
        XCTAssertFalse(energy.label.contains("100"))
        XCTAssertFalse(energy.label.contains("%"))
        let stress = card("stress", in: app)
        XCTAssertTrue(stress.label.contains("较高") && stress.label.contains("仅心率估算"))
        XCTAssertFalse(stress.label.contains("83"))
    }

    @MainActor func testThreeProductionDestinations_TC_PTC_005() {
        for (kind, title) in [("readiness", "训练准备度"), ("energy", "身体电量"), ("stress", "生理压力")] {
            let anchor = Date()
            let app = launch(fixtureDate: anchor)
            card(kind, in: app).tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 3))
            XCTAssertTrue(app.otherElements["metric.detail.score"].exists || app.staticTexts["metric.detail.score"].exists)
            if kind == "readiness" {
                XCTAssertTrue(find("metric.detail.contribution.hrv", in: app).exists)
            }
            XCTAssertTrue(find("metric.detail.dataTime", in: app).label.contains(timestamp(anchor.addingTimeInterval(-7200))))
            XCTAssertTrue(find("metric.detail.reportTime", in: app).label.contains(timestamp(anchor.addingTimeInterval(-5400))))
            goBack(in: app)
            XCTAssertTrue(card(kind, in: app).exists)
            app.terminate()
        }
    }

    @MainActor func testZeroSurvivesInDetail_TC_PTC_002_005() {
        let app = launch()
        card("energy", in: app).tap()
        let score = find("metric.detail.score", in: app)
        XCTAssertTrue(score.label.contains("0 分"))
        XCTAssertFalse(score.label.contains("暂无数据"))
    }

    @MainActor func testMissingHasReasonAndUnknownSource_TC_PTC_003_005() {
        let app = launch(["--missing"])
        let energy = card("energy", in: app)
        XCTAssertTrue(energy.label.contains("暂无可读取记录"))
        XCTAssertFalse(energy.label.contains("身体电量估算"))
        energy.tap()
        XCTAssertTrue(find("metric.detail.source", in: app).label.contains("暂无报告"))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "metric.detail.reportTime").firstMatch.exists)
    }

    @MainActor func testForegroundExpiry_TC_PTC_004() {
        let app = launch(["--expires"])
        let readiness = card("readiness", in: app)
        XCTAssertTrue(readiness.label.contains("接近个人常态"))
        app.buttons["fixture.expire"].tap()
        let expired = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "数据已过期"), object: readiness)
        XCTAssertEqual(XCTWaiter.wait(for: [expired], timeout: 42), .completed)
        readiness.tap()
        XCTAssertTrue(find("metric.detail.score", in: app).label.contains("暂无数据"))
    }

    @MainActor func testDemoFreezesReportClock_TC_PTC_004_005() {
        let app = launch(["--expires", "--demo-freeze"])
        XCTAssertTrue(app.staticTexts["合成演示 · 非健康评估"].exists)
        let readiness = card("readiness", in: app)
        app.buttons["fixture.expire"].tap()
        let staysCurrent = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "数据已过期"), object: readiness)
        staysCurrent.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [staysCurrent], timeout: 35), .completed)
        XCTAssertTrue(readiness.label.contains("接近个人常态"))
    }

    @MainActor func testOpenDetailExpiresAndHidesContributions_TC_PTC_004_005() {
        let app = launch(["--expires"])
        card("readiness", in: app).tap()
        XCTAssertTrue(find("metric.detail.contribution.hrv", in: app).exists)
        app.buttons["fixture.expire"].tap()
        app.swipeDown()
        let score = find("metric.detail.score", in: app)
        let expired = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "暂无数据"), object: score)
        XCTAssertEqual(XCTWaiter.wait(for: [expired], timeout: 42), .completed)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "metric.detail.contribution.hrv").firstMatch.exists)
    }

    @MainActor func testResumeReevaluatesClock_TC_PTC_004() {
        let app = launch(["--expires"])
        XCTAssertTrue(card("readiness", in: app).label.contains("接近个人常态"))
        app.buttons["fixture.expire"].tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.activate()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) || app.state == .runningBackgroundSuspended,
                      "The care app must actually enter the background before testing its return.")
        let deadline = XCTNSPredicateExpectation(predicate: NSPredicate(value: false), object: nil)
        deadline.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [deadline], timeout: 10), .completed)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        let refreshed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "数据已过期"), object: app.buttons["care.readiness"])
        XCTAssertEqual(XCTWaiter.wait(for: [refreshed], timeout: 4), .completed)
    }

    private func timestamp(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.year().month(.twoDigits).day(.twoDigits)
            .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)
        style.locale = Locale(identifier: "zh_CN")
        style.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return date.formatted(style)
    }

    @MainActor private func goBack(in app: XCUIApplication) {
        let button = app.navigationBars.buttons.firstMatch
        if button.exists { button.tap() }
        else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    @MainActor func testLargestTypeCardsRemainNavigable_TC_PTC_006() {
        let app = launch(["--large-type"])
        for kind in ["readiness", "energy", "stress"] {
            let element = card(kind, in: app)
            XCTAssertTrue(element.isHittable)
            XCTAssertLessThanOrEqual(element.frame.maxX, app.frame.maxX)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Largest type \(kind)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.swipeUp()
            let continuation = XCTAttachment(screenshot: app.screenshot())
            continuation.name = "Largest type \(kind) continuation"
            continuation.lifetime = .keepAlways
            add(continuation)
        }
        card("stress", in: app).tap()
        XCTAssertTrue(app.navigationBars["生理压力"].exists)
    }

    @MainActor func testLargestTypeMissingReasons_TC_PTC_003_006() {
        let app = launch(["--missing", "--large-type"])
        let energy = card("energy", in: app)
        XCTAssertTrue(energy.label.contains("暂无可读取记录"))
        XCTAssertTrue(energy.label.contains("没有可读取结果并不能证明读取权限被拒绝"))
        app.swipeUp()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Largest type long missing reason"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        card("stress", in: app).tap()
        XCTAssertTrue(app.navigationBars["生理压力"].exists)
    }

    @MainActor func testMixedHeightCardsAlign_TC_PCL_001() {
        let app = launch(["--mixed-heights"])
        let energy = card("energy", in: app)
        let stress = card("stress", in: app)
        XCTAssertTrue(energy.isHittable && stress.isHittable)
        XCTAssertEqual(energy.frame.minY, stress.frame.minY, accuracy: 1)
        XCTAssertEqual(energy.frame.height, stress.frame.height, accuracy: 1)
        XCTAssertTrue(energy.label.contains("夜间基线不足 · 9/14天"))
        XCTAssertTrue(energy.label.contains("不保证经过14个自然日就能出分"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Mixed height cards"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        energy.tap()
        XCTAssertTrue(app.navigationBars["身体电量"].waitForExistence(timeout: 3))
        goBack(in: app)
        card("stress", in: app).tap()
        XCTAssertTrue(app.navigationBars["生理压力"].waitForExistence(timeout: 3))
    }

    @MainActor func testLargestTypeMixedHeightsStack_TC_PCL_002() {
        let app = launch(["--mixed-heights", "--large-type"])
        let energy = card("energy", in: app)
        XCTAssertTrue(energy.label.contains("不保证经过14个自然日就能出分"))
        let stress = card("stress", in: app)
        XCTAssertLessThanOrEqual(energy.frame.maxY, stress.frame.minY + 0.5)
        XCTAssertLessThanOrEqual(stress.frame.maxX, app.frame.maxX)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Largest type mixed height cards"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        stress.tap()
        XCTAssertTrue(app.navigationBars["生理压力"].waitForExistence(timeout: 3))
        goBack(in: app)
        card("energy", in: app).tap()
        XCTAssertTrue(app.navigationBars["身体电量"].waitForExistence(timeout: 3))
    }

    #if FULL_APP_CARE_PROBE
    @MainActor func testFullAppTodayNavigation_TC_PTC_005_006() {
        let app = XCUIApplication(bundleIdentifier: "com.mirsery.wristlab")
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["合成演示 · 非健康评估"].waitForExistence(timeout: 10))
        let readiness = card("readiness", in: app)
        XCTAssertTrue(readiness.isHittable)
        XCTAssertFalse(readiness.label.contains("100"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Full app narrow today care"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        readiness.tap()
        XCTAssertTrue(app.navigationBars["训练准备度"].waitForExistence(timeout: 3))
        goBack(in: app)
        for title in ["睡眠", "活动", "趋势", "我的", "今天"] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.exists)
            tab.tap()
            XCTAssertTrue(tab.isSelected)
        }
        XCTAssertTrue(card("energy", in: app).isHittable)
        let metrics = XCTAttachment(screenshot: app.screenshot())
        metrics.name = "Full app narrow energy and stress"
        metrics.lifetime = .keepAlways
        add(metrics)
    }

    @MainActor private func launchFullApp() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "com.mirsery.wristlab")
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["合成演示 · 非健康评估"].waitForExistence(timeout: 10))
        return app
    }

    /// Largest channel difference from wristBackground inside a band of the screenshot (points).
    @MainActor private func backgroundDeviation(_ screenshot: XCUIScreenshot, in app: XCUIApplication,
                                                x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>) -> Int {
        guard let image = screenshot.image.cgImage,
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return .max }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data?.assumingMemoryBound(to: UInt8.self) else { return .max }
        let scale = CGFloat(image.height) / app.frame.height
        let background = [9, 14, 19]
        var worst = 0
        for row in Int(y.lowerBound * scale)..<Int(y.upperBound * scale) {
            for column in Int(x.lowerBound * app.frame.width * scale)..<Int(x.upperBound * app.frame.width * scale) {
                let offset = (row * image.width + column) * 4
                for channel in 0..<3 { worst = max(worst, abs(Int(data[offset + channel]) - background[channel])) }
            }
        }
        return worst
    }

    @MainActor func testScrolledContentStaysOutOfStatusBar_TC_PCL_003() {
        let app = launchFullApp()
        // XCUITest still lists identified containers hidden from VoiceOver, so check geometry and inertness.
        let backdrop = app.otherElements["today.statusBarBackdrop"]
        XCTAssertTrue(backdrop.exists)
        XCTAssertEqual(backdrop.frame.minY, 0, accuracy: 0.5)
        XCTAssertFalse(backdrop.isHittable)
        guard backdrop.frame.height >= 20 else { return XCTFail("Backdrop does not cover the status bar: \(backdrop.frame)") }
        // Drag the synthetic status card under the status bar so the band has content behind it.
        let status = app.staticTexts["合成演示 · 非健康评估"]
        let distance = (status.frame.midY - backdrop.frame.midY) / app.frame.height
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8 - distance)),
                    withVelocity: .slow, thenHoldForDuration: 0.5)
        sleep(1)
        let band = (backdrop.frame.minY + 4)...(backdrop.frame.maxY - 4)
        XCTAssertTrue(status.frame.minY < band.upperBound && status.frame.maxY > band.lowerBound, "\(status.frame)")
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Scrolled today status bar"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Band between the clock and the right status icons (Face ID devices).
        XCTAssertLessThanOrEqual(backgroundDeviation(screenshot, in: app, x: 0.32...0.64, y: band), 4)
    }

    @MainActor func testLastTodayCardClearsTabBar_TC_PCL_004() {
        let app = launchFullApp()
        for _ in 0..<8 { app.swipeUp() }
        sleep(1)
        let activity = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "报告日活动")).firstMatch
        XCTAssertTrue(activity.exists, app.debugDescription)
        let settled = activity.frame
        app.swipeUp()
        sleep(1)
        XCTAssertEqual(activity.frame.minY, settled.minY, accuracy: 1, "not scrolled to the end")
        XCTAssertLessThanOrEqual(activity.frame.maxY, app.tabBars.firstMatch.frame.minY + 0.5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Today bottom above tab bar"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    #endif
}
