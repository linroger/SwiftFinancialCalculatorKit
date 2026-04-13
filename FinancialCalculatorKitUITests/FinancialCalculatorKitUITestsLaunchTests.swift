//
//  FinancialCalculatorKitUITestsLaunchTests.swift
//  FinancialCalculatorKitUITests
//
//  Created by Roger Lin on 6/9/25.
//

import XCTest

final class FinancialCalculatorKitUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
