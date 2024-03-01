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
      let recoreonPathService = RecoreonPathService(fileManager)
      let screenRecordService = ScreenRecordService(FileManager.default, recoreonPathService)
      ContentView(
        screenRecordService: screenRecordService,
        screenRecordStore: ScreenRecordStore(screenRecordService: screenRecordService)
      )
    }
  }
}
