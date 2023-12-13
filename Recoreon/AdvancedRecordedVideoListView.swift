import AVKit
import ReplayKit
import SwiftUI

let byteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useMB, .useGB]
  return bcf
}()

struct AdvancedRecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore
  @Binding var path: NavigationPath

  var body: some View {
    NavigationStack(path: $path) {
      List {
        ForEach(recordedVideoStore.recordedVideoEntries) { entry in
          NavigationLink(
            value: AdvancedRecordedVideoDetailViewRoute(
              recordedVideoEntry: entry
            )
          ) {
            VStack {
              HStack {
                Text(entry.url.lastPathComponent)
                Spacer()
              }
              HStack {
                Text(entry.creationDate.formatted())
                Text(byteCountFormatter.string(fromByteCount: Int64(entry.size)))
                Spacer()
              }
            }
          }
        }
      }
      .navigationTitle("List of recorded videos")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: AdvancedRecordedVideoDetailViewRoute.self) { route in
        AdvancedRecordedVideoDetailView(
          recordedVideoService: recordedVideoService,
          recordedVideoStore: recordedVideoStore,
          path: $path,
          recordedVideoEntry: route.recordedVideoEntry
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
