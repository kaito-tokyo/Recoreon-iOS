import AVKit
import SwiftUI
import HLSServer

struct ScreenRecordPreviewViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordPreviewView: View {
  let recoreonServices: RecoreonServices
  let screenRecordEntry: ScreenRecordEntry

  func openHLSServer(fragmentedRecordURL: URL) -> HLSServer? {
    return try? HLSServer(
      htdocs: screenRecordEntry.url.path(percentEncoded: false),
      host: "::1"
    )
  }

  func getMasterPlaylistRemoteURL(
    server: HLSServer?,
    fragmentedRecordURL: URL
  ) -> URL? {
    guard let port = server?.port else { return nil }

    let recoreonPathService = recoreonServices.recoreonPathService

    let masterPlaylistName = recoreonPathService.getMasterPlaylistURL(
      fragmentedRecordURL: screenRecordEntry.url
    ).lastPathComponent

    let masterPlaylistRemoteURL = URL(
      string: "http://[::1]:\(port)/\(masterPlaylistName)"
    )

    return masterPlaylistRemoteURL
  }

  func createPreviewPlayer(masterPlaylistRemoteURL: URL?) -> AVPlayer {
    if let masterPlaylistRemoteURL = masterPlaylistRemoteURL {
      return AVPlayer(url: masterPlaylistRemoteURL)
    } else {
      return AVPlayer()
    }
  }

  var body: some View {
    let server = openHLSServer(
      fragmentedRecordURL: screenRecordEntry.url
    )

    let masterPlaylistRemoteURL = getMasterPlaylistRemoteURL(
      server: server,
      fragmentedRecordURL: screenRecordEntry.url
    )

    let player: AVPlayer = createPreviewPlayer(
      masterPlaylistRemoteURL: masterPlaylistRemoteURL
    )

    VideoPlayer(player: player)
      .accessibilityIdentifier("PreviewVideoPlayer")
      .onDisappear {
        player.pause()
        Task {
          try await server?.close()
        }
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
