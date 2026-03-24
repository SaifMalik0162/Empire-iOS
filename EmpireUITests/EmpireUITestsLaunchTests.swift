//
//  EmpireUITestsLaunchTests.swift
//  EmpireUITests
//
//  Created by Saif Malik on 2026-01-06.
//

import XCTest

final class EmpireUITestsLaunchTests: XCTestCase {
    private let supabaseURL = "https://matwihdeczmkdvsbuxvv.supabase.co"
    private let supabaseAnonKey = "sb_publishable_Bd_9Istn0C4ep16Qg2M1RA_FCHJW4Bf"

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["SUPABASE_URL"] = supabaseURL
        app.launchEnvironment["SUPABASE_ANON_KEY"] = supabaseAnonKey
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
