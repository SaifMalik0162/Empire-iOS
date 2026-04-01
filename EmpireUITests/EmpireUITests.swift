//
//  EmpireUITests.swift
//  EmpireUITests
//
//  Created by Saif Malik on 2026-01-06.
//

import XCTest

final class EmpireUITests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testLaunchShowsLoginScreen() throws {
        let app = XCUIApplication()
        applySecurityConfig(to: app)
        app.launch()

        XCTAssertTrue(app.staticTexts["Welcome back to Empire"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue with Apple"].exists)
        XCTAssertTrue(app.buttons["Continue with Google"].exists)
    }

    @MainActor
    func testForgotPasswordFlowOpensResetSheet() throws {
        let app = XCUIApplication()
        applySecurityConfig(to: app)
        app.launch()

        XCTAssertTrue(app.buttons["Forgot password?"].waitForExistence(timeout: 5))
        app.buttons["Forgot password?"].tap()

        XCTAssertTrue(app.staticTexts["Reset your password"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Send Reset Link"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            applySecurityConfig(to: app)
            app.launch()
        }
    }

    private func applySecurityConfig(to app: XCUIApplication) {
        let environment = ProcessInfo.processInfo.environment
        if let url = environment["SUPABASE_URL"], !url.isEmpty {
            app.launchEnvironment["SUPABASE_URL"] = url
        }
        if let anonKey = environment["SUPABASE_ANON_KEY"], !anonKey.isEmpty {
            app.launchEnvironment["SUPABASE_ANON_KEY"] = anonKey
        }
    }
}
