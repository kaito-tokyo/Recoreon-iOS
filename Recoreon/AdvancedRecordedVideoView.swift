import SwiftUI

struct AdvancedRecordedVideoView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore

  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      AdvancedRecordedVideoListView(
        recordedVideoService: recordedVideoService,
        recordedVideoStore: recordedVideoStore,
        path: $path
      )
    }
  }
}
