//
//  RecoreonUITests.swift
//  RecoreonUITests
//
//  Created by Kaito Udagawa on 2023/11/01.
//

import XCTest

final class RecoreonUITests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // In UI tests it’s important to set the initial state -
    // such as interface orientation - required for your tests before
    // they run. The setUp method is a good place to do this.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func launchWithUITestMode() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UITest"]
    app.launch()
    return app
  }

  func testScreenRecordListViewCanBeShown() throws {
    let app = launchWithUITestMode()

    XCTAssert(app.staticTexts["List of screen records"].waitForExistence(timeout: 10))
  }

  func testScreenRecordDetailViewCanBeShown() throws {
    let app = launchWithUITestMode()

    app.buttons.matching(identifier: "ScreenRecordEntry").element(boundBy: 0).tap()
    XCTAssert(app.staticTexts["Preview"].waitForExistence(timeout: 10))
  }

  func testScreenRecordPreviewViewCanBeShown() throws {
    let app = launchWithUITestMode()

    app.buttons.matching(identifier: "ScreenRecordEntry").element(boundBy: 0).tap()
    app.buttons["PreviewButton"].tap()
    XCTAssert(app.otherElements["PreviewVideoPlayer"].waitForExistence(timeout: 10))
  }

  func testScreenRecordEncodeViewCanBeShown() throws {
    let app = launchWithUITestMode()

    app.buttons.matching(identifier: "ScreenRecordEntry").element(boundBy: 0).tap()
    app.buttons["EncodeButton"].tap()
    XCTAssert(app.staticTexts["Preset"].waitForExistence(timeout: 10))
  }

  func testRecordNoteEditorViewCanBeShown() throws {
    let app = launchWithUITestMode()

    app.buttons.matching(identifier: "ScreenRecordEntry").element(boundBy: 1).tap()
    app.buttons.matching(identifier: "RecordNoteEntryButton").element(boundBy: 0).tap()
    XCTAssert(app.staticTexts["Record01-1.txt"].waitForExistence(timeout: 10))
  }

  //  func testLaunchPerformance() throws {
  //    if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
  //      // This measures how long it takes to launch your application.
  //      measure(metrics: [XCTApplicationLaunchMetric()]) {
  //        XCUIApplication().launch()
  //      }
  //    }
  //  }
}
