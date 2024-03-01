//
//  RecoreonApp.swift
//  Recoreon
//
//  Created by Kaito Udagawa on 2023/11/01.
//

import SwiftUI

@main
struct RecoreonApp: App {
  var body: some Scene {
    WindowGroup {
      let fileManager = FileManager.default
      let recoreonPathService = RecoreonPathService(fileManager: fileManager)
      let screenRecordService = ScreenRecordService(
        fileManager: fileManager, recoreonPathService: recoreonPathService)
      ContentView(
        screenRecordService: screenRecordService,
        screenRecordStore: ScreenRecordStore(screenRecordService: screenRecordService)
      )
    }
  }
}
