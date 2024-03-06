import RecoreonCommon
import SwiftUI

@main
struct RecoreonApp: App {
  var body: some Scene {
    #if DEBUG
    let recoreonServices: RecoreonServices = {
      if ProcessInfo.processInfo.arguments.contains("-UITest") {
        let recoreonServices = PreviewRecoreonServices()
        recoreonServices.recoreonPathService.wipeRecordNotes()
        recoreonServices.deployAllAssets()
        return PreviewRecoreonServices()
      } else {
        return DefaultRecoreonServices()
      }
    }()
    #else
    let recoreonServices = DefaultRecoreonServices()
    #endif
    WindowGroup {
      ContentView(recoreonServices: recoreonServices)
    }
  }
}
