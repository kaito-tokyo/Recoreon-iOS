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
      let service = ScreenRecordService()
      ContentView(
        screenRecordService: service,
        screenRecordStore: ScreenRecordStore(screenRecordService: service)
      )
    }
  }
}