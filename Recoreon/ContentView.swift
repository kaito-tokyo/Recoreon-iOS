import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @State var recordedVideoEntries: [RecordedVideoEntry] = []

  var body: some View {
    TabView {
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
      RecordedVideoBasicView(recordedVideoManipulator: recordedVideoManipulator)
        .tabItem { Image(systemName: "rectangle.grid.3x2") }
      RecordedVideoAdvancedView(recordedVideoManipulator: recordedVideoManipulator, recordedVideoEntries: $recordedVideoEntries)
        .tabItem { Image(systemName: "list.bullet") }
    }.onAppear {
      recordedVideoEntries = recordedVideoManipulator.listVideoEntries()
    }
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}
