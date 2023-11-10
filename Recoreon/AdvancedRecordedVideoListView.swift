import AVKit
import ReplayKit
import SwiftUI

struct AdvancedRecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService

  @Binding var recordedVideoEntries: [RecordedVideoEntry]

  var body: some View {
    NavigationStack {
      List {
        ForEach(recordedVideoEntries) { entry in
          NavigationLink {
            AdvancedRecordedVideoDetailView(
              recordedVideoService: recordedVideoService,
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
    let service = RecordedVideoServiceMock()
    @State var entries = service.listRecordedVideoEntries()

    return AdvancedRecordedVideoListView(
      recordedVideoService: service,
      recordedVideoEntries: $entries
    )
  }
#endif
