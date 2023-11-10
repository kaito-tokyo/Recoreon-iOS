import AVKit
import ReplayKit
import SwiftUI

struct AdvancedRecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore
  @Binding var path: NavigationPath

  var body: some View {
    NavigationStack(path: $path) {
      List {
        ForEach(recordedVideoStore.recordedVideoEntries) { entry in
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
          recordedVideoStore: recordedVideoStore,
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
    @StateObject var store = RecordedVideoStore(recordedVideoService: service)

    return NavigationStack {
      AdvancedRecordedVideoListView(
        recordedVideoService: service,
        recordedVideoStore: store,
        path: $path
      )
    }
  }
#endif
