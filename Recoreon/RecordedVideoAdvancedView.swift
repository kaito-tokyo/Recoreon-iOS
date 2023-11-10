import AVKit
import ReplayKit
import SwiftUI

struct RecordedVideoAdvancedView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @Binding var recordedVideoEntries: [RecordedVideoEntry]

  @State var player = AVPlayer()
  @State var isPresentedPlayer: Bool = false
  @State var isPresentedRemuxing: Bool = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(recordedVideoEntries) { entry in
          NavigationLink {
            RecordedVideoAdvancedDetailView(
              recordedVideoManipulator: recordedVideoManipulator,
              recordedVideoEntry: entry
            )
          } label: {
            VStack {
              HStack {
                Text(entry.url.lastPathComponent)
                Spacer()
              }
              HStack {
                Text(Date().formatted())
                Text("1GB")
                Spacer()
              }
            }
          }
        }
      }
      .navigationTitle("List of recorded videos")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#if DEBUG
  #Preview {
    let recordedVideoManipulator = RecordedVideoManipulatorMock()
    @State var recordedVideoEntries = recordedVideoManipulator.listVideoEntries()

    return RecordedVideoAdvancedView(
      recordedVideoManipulator: RecordedVideoManipulatorMock(),
      recordedVideoEntries: $recordedVideoEntries)
  }
#endif
