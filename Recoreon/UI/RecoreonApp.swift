import SwiftUI
import RecoreonCommon

@main
struct RecoreonApp: App {
  var body: some Scene {
    #if DEBUG
      let recoreonServices: RecoreonServices = {
        if ProcessInfo.processInfo.arguments.contains("-UITest") {
          RecoreonPathService(fileManager: FileManager.default).wipeRecordNotes()
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
