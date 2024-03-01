import ReplayKit
import SwiftUI

struct ContentView: View {
  let screenRecordService: ScreenRecordService

  @StateObject private var screenRecordStore: ScreenRecordStore

  @Environment(\.scenePhase) private var scenePhase

  init(screenRecordService: ScreenRecordService, screenRecordStore: ScreenRecordStore) {
    self.screenRecordService = screenRecordService
    self._screenRecordStore = StateObject(wrappedValue: screenRecordStore)
  }

  var body: some View {
    TabView {
      ScreenRecordView(
        screenRecordService: screenRecordService,
        screenRecordStore: screenRecordStore
      )
      .tabItem { Image(systemName: "list.bullet") }
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        screenRecordStore.update()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = ScreenRecordServiceMock()

    return ContentView(
      screenRecordService: service,
      screenRecordStore: ScreenRecordStore(
        screenRecordService: service
      )
    )
  }
#endif
