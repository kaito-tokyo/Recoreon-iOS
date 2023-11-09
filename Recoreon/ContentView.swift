import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol

  var body: some View {
    TabView {
      Text("Record")
        .tabItem { Image(systemName: "record.circle") }
      RecordedVideoBasicView(recordedVideoManipulator: recordedVideoManipulator)
        .tabItem { Image(systemName: "rectangle.grid.3x2" ) }
      Text("Advenced View")
        .tabItem { Image(systemName: "list.bullet") }
    }
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}
