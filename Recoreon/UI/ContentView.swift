import ReplayKit
import SwiftUI

struct ContentView: View {
  @StateObject var recoreonServiceStore: RecoreonServiceStore

  init(recoreonServiceStore: RecoreonServiceStore? = nil) {
    let fileManager = FileManager.default
    if let recoreonServiceStore = recoreonServiceStore {
      _recoreonServiceStore = StateObject(wrappedValue: recoreonServiceStore)
    } else {
      let recoreonPathService = DefaultRecoreonPathService(fileManager: fileManager)

      let encodeService = DefaultEncodeService(
        fileManager: fileManager, recoreonPathService: recoreonPathService)
      let recordNoteService = DefaultRecordNoteService(recoreonPathService: recoreonPathService)
      let screenRecordService = DefaultScreenRecordService(
        fileManager: fileManager, recoreonPathService: recoreonPathService)
      let recoreonServiceStore = RecoreonServiceStore(
        recoreonPathService: recoreonPathService,
        encodeService: encodeService,
        recordNoteService: recordNoteService,
        screenRecordService: screenRecordService
      )
      _recoreonServiceStore = StateObject(wrappedValue: recoreonServiceStore)
    }
  }

  var body: some View {
    TabView {
      ScreenRecordView(recoreonServiceStore: recoreonServiceStore)
        .tabItem { Image(systemName: "list.bullet") }
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
    }
  }
}

#if DEBUG
  #Preview {
    ContentView(recoreonServiceStore: previewRecoreonServiceStore)
  }
#endif
