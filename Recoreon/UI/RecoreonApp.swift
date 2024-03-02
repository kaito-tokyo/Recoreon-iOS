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
      let recoreonServices = DefaultRecoreonServices()
      ContentView(
        recoreonServices: recoreonServices,
        screenRecordStore: ScreenRecordStore(
          screenRecordService: recoreonServices.screenRecordService)
      )
    }
  }
}
