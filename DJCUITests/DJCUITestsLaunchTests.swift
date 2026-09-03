//
//  DJCUITestsLaunchTests.swift
//  DJCUITests
//
//  Created by Ярослав Сорелля on 01.09.2026.
//

import XCTest

final class DJCUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
    }
}
