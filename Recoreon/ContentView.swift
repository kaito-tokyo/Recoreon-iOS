import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol

  var body: some View {
    RecordedVideoBasicView(recordedVideoManipulator: recordedVideoManipulator)
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}
