import AVKit
import ReplayKit
import SwiftUI

struct AdvancedRecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService
  let recordedVideoEntries: [RecordedVideoEntry]
  @Binding var path: NavigationPath

  var body: some View {
    NavigationStack(path: $path) {
      List {
        ForEach(recordedVideoEntries) { entry in
          NavigationLink(value: entry) {
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
      .navigationDestination(for: RecordedVideoEntry.self) { entry in
        AdvancedRecordedVideoDetailView(
          recordedVideoService: recordedVideoService,
          path: $path,
          recordedVideoEntry: entry
        )
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    @State var entries = service.listRecordedVideoEntries()
    @State var path = NavigationPath()

    return NavigationStack {
      AdvancedRecordedVideoListView(
        recordedVideoService: service,
        recordedVideoEntries: entries,
        path: $path
      )
    }
  }
#endif
