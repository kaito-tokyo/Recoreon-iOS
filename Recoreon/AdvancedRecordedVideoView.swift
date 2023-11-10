import SwiftUI

struct AdvancedRecordedVideoView: View {
  let recordedVideoService: RecordedVideoService
  let recordedVideoEntries: [RecordedVideoEntry]

  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      AdvancedRecordedVideoListView(
        recordedVideoService: recordedVideoService,
        recordedVideoEntries: recordedVideoEntries,
        path: $path
      )
    }
  }
}
