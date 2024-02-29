import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoService: RecordedVideoService

  @StateObject private var recordedVideoStore: RecordedVideoStore

  @Environment(\.scenePhase) private var scenePhase

  init(recordedVideoService: RecordedVideoService, recordedVideoStore: RecordedVideoStore) {
    self.recordedVideoService = recordedVideoService
    self._recordedVideoStore = StateObject(wrappedValue: recordedVideoStore)
  }

  var body: some View {
    TabView {
      RecordedVideoView(
        recordedVideoService: recordedVideoService,
        recordedVideoStore: recordedVideoStore
      )
      .tabItem { Image(systemName: "list.bullet") }
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        recordedVideoStore.update()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()

    return ContentView(
      recordedVideoService: service,
      recordedVideoStore: RecordedVideoStore(
        recordedVideoService: service
      )
    )
  }
#endif
