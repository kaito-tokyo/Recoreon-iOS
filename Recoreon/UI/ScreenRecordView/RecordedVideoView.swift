import SwiftUI

struct RecordedVideoView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore

  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      RecordedVideoListView(
        recordedVideoService: recordedVideoService,
        recordedVideoStore: recordedVideoStore,
        path: $path
      )
    }
  }
}
