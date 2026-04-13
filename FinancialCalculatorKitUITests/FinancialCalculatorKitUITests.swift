//
//  FinancialCalculatorKitUITests.swift
//  FinancialCalculatorKitUITests
//
//  Created by Roger Lin on 6/9/25.
//

import XCTest

final class FinancialCalculatorKitUITests: XCTestCase {

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
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()

        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["New Calculation"].waitForExistence(timeout: 2))
        app.buttons["Cancel"].tap()

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Preferences"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()

        app.typeKey("/", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["Help & Documentation"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()

        let loanCalculatorLink = app.buttons["Loan Calculator"].firstMatch
        XCTAssertTrue(loanCalculatorLink.waitForExistence(timeout: 2))
        loanCalculatorLink.tap()
        XCTAssertTrue(app.staticTexts["Calculate loan payments, interest costs, and payment schedules for various types of loans."].waitForExistence(timeout: 2))
    }

}
