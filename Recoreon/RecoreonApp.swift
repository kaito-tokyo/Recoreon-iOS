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
      let service = RecordedVideoService()
      ContentView(
        recordedVideoService: service,
        recordedVideoStore: RecordedVideoStore(recordedVideoService: service)
      )
    }
  }
}
