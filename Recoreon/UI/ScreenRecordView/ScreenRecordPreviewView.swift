import AVKit
import SwiftUI

struct ScreenRecordPreviewViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordPreviewView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  let player = AVPlayer()

  @State var isRemuxing: Bool = false
  @State var isRemuxingFailed: Bool = false

  @State var isShowingRemoveConfirmation = false

  var body: some View {
    ZStack {
      VideoPlayer(player: player)
        .onAppear {
          Task {
            isRemuxing = true
            guard let previewURL = await screenRecordService.remux(screenRecordEntry.url) else {
              isRemuxingFailed = true
              isRemuxing = false
              return
            }
            player.replaceCurrentItem(with: AVPlayerItem(url: previewURL))
            isRemuxing = false
            player.play()
          }
        }
        .onDisappear {
          player.pause()
        }
      if isRemuxing {
        ProgressView()
          .tint(.white)
          .scaleEffect(CGSize(width: 10, height: 10))
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = ScreenRecordServiceMock()
    let entries = service.listScreenRecordEntries()
    @State var selectedEntry = entries.first!
    @State var path: NavigationPath = NavigationPath()
    @StateObject var store = ScreenRecordStore(screenRecordService: service)

    return NavigationStack {
      ScreenRecordPreviewView(
        screenRecordService: service,
        screenRecordStore: store,
        path: $path,
        screenRecordEntry: selectedEntry
      )
    }
  }
#endif