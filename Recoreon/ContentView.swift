import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @State var recordedVideoEntries: [RecordedVideoEntry] = []

  @State var recordedVideoURLs: [URL] = []

  var body: some View {
    TabView {
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
      RecordedVideoBasicView(
        recordedVideoManipulator: recordedVideoManipulator,
        recordedVideoEntries: $recordedVideoEntries
      )
      .tabItem { Image(systemName: "rectangle.grid.3x2") }
      RecordedVideoAdvancedView(
        recordedVideoManipulator: recordedVideoManipulator,
        recordedVideoEntries: $recordedVideoEntries,
        recordedVideoURLs: $recordedVideoURLs
      )
      .tabItem { Image(systemName: "list.bullet") }
    }.onAppear {
      recordedVideoEntries = recordedVideoManipulator.listVideoEntries()
      recordedVideoURLs = recordedVideoManipulator.listRecordedVideoURLs()
    }
  }
}

#if DEBUG
  #Preview {
    ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
  }
#endif
