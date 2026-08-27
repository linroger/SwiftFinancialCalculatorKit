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
        let newCalculationTitle = app.staticTexts["New Calculation"]
        XCTAssertTrue(newCalculationTitle.waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        // Wait for the sheet to fully dismiss before presenting the next one —
        // SwiftUI drops a present issued during another sheet's dismissal.
        XCTAssertTrue(waitForDisappearance(of: newCalculationTitle, timeout: 5))

        app.typeKey(",", modifierFlags: .command)
        let preferencesTitle = app.staticTexts["Preferences"]
        XCTAssertTrue(preferencesTitle.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(waitForDisappearance(of: preferencesTitle, timeout: 5))

        app.typeKey("/", modifierFlags: [.command, .shift])
        let helpTitle = app.staticTexts["Help & Documentation"]
        XCTAssertTrue(helpTitle.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(waitForDisappearance(of: helpTitle, timeout: 5))

        let loanCalculatorLink = app.buttons["Loan Calculator"].firstMatch
        XCTAssertTrue(loanCalculatorLink.waitForExistence(timeout: 5))
        loanCalculatorLink.tap()
        XCTAssertTrue(app.staticTexts["Calculate loan payments, interest costs, and payment schedules for various types of loans."].waitForExistence(timeout: 5))
    }

    @MainActor
    private func waitForDisappearance(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

}
