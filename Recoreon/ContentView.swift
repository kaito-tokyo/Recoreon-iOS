import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol

  var body: some View {
    TabView {
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
      RecordedVideoBasicView(recordedVideoManipulator: recordedVideoManipulator)
        .tabItem { Image(systemName: "rectangle.grid.3x2" ) }
      RecordedVideoAdvancedView()
        .tabItem { Image(systemName: "list.bullet") }
    }
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}
