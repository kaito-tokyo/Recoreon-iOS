import AVKit
import ReplayKit
import SwiftUI

struct RecordedVideoAdvancedView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @Binding var recordedVideoEntries: [RecordedVideoEntry]
  @Binding var recordedVideoURLs: [URL]

  @State var player = AVPlayer()
  @State var isPresentedPlayer: Bool = false
  @State var isPresentedRemuxing: Bool = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(recordedVideoURLs, id: \.lastPathComponent) { url in
          NavigationLink {
            RecordedVideoAdvancedDetailView(
              recordedVideoManipulator: recordedVideoManipulator,
              recordedVideoEntry: RecordedVideoEntry(
                url: url,
                uiImage: UIImage()
              ), recordedVideoURL: url
            )
          } label: {
            VStack {
              HStack {
                Text(url.lastPathComponent)
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
    @State var recordedVideoURLs = recordedVideoManipulator.listRecordedVideoURLs()

    return RecordedVideoAdvancedView(
      recordedVideoManipulator: RecordedVideoManipulatorMock(),
      recordedVideoEntries: $recordedVideoEntries, recordedVideoURLs: $recordedVideoURLs)
  }
#endif
