import AVKit
import SwiftUI
import Swifter

struct ScreenRecordPreviewViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordPreviewView: View {
  let recoreonServices: RecoreonServices
  let screenRecordEntry: ScreenRecordEntry

  var body: some View {
    let recoreonPathService = recoreonServices.recoreonPathService
    let masterPlaylistURL = recoreonPathService.getMasterPlaylistURL(fragmentedRecordURL: screenRecordEntry.url)
    let server = demoServer(screenRecordEntry.url.path(percentEncoded: false))
    let _ = try? server.start(47510)

    let player = AVPlayer(url: URL(string: "http://localhost:47510/public/\(masterPlaylistURL.lastPathComponent)")!)

    VideoPlayer(player: player)
      .accessibilityIdentifier("PreviewVideoPlayer")
      .onDisappear {
        player.pause()
      }
  }
}

#if DEBUG
struct ScreenRecordPreviewViewContainer: View {
  let recoreonServices: RecoreonServices
  let screenRecordEntry: ScreenRecordEntry

  var body: some View {
    TabView {
      NavigationStack {
        ScreenRecordPreviewView(
          recoreonServices: recoreonServices,
          screenRecordEntry: screenRecordEntry
        )
      }
    }
  }
}

#Preview {
  let recoreonServices = PreviewRecoreonServices()
  recoreonServices.recoreonPathService.wipe()
  recoreonServices.deployAllAssets()
  let screenRecordService = recoreonServices.screenRecordService
  let screenRecordEntries = screenRecordService.listScreenRecordEntries()
  let screenRecordEntry = screenRecordEntries[0]

  return ScreenRecordPreviewViewContainer(
    recoreonServices: recoreonServices,
    screenRecordEntry: screenRecordEntry
  )
}
#endif
