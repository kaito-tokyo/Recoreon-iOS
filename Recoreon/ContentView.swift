import ReplayKit
import SwiftUI

struct ContentView: View {
  let recordedVideoService: RecordedVideoService
  @State var recordedVideoEntries: [RecordedVideoEntry]

  var body: some View {
    TabView {
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
      //      RecordedVideoBasicView(
      //        recordedVideoService: recordedVideoService,
      //        recordedVideoEntries: $recordedVideoEntries
      //      )
      //      .tabItem { Image(systemName: "rectangle.grid.3x2") }
      AdvancedRecordedVideoListView(
        recordedVideoService: recordedVideoService,
        recordedVideoEntries: $recordedVideoEntries
      )
      .tabItem { Image(systemName: "list.bullet") }
    }.onAppear {
      recordedVideoEntries = recordedVideoService.listRecordedVideoEntries()
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()

    return ContentView(
      recordedVideoService: service,
      recordedVideoEntries: service.listRecordedVideoEntries()
    )
  }
#endif
