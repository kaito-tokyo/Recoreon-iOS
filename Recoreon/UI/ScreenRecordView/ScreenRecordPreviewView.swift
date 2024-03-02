import AVKit
import SwiftUI

struct ScreenRecordPreviewViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordPreviewView: View {
  let screenRecordService: ScreenRecordService
  let screenRecordEntry: ScreenRecordEntry

  let player = AVPlayer()

  @State var isRemuxing: Bool = false

  @State var isShowingRemoveConfirmation = false

  var body: some View {
    ZStack {
      VideoPlayer(player: player)
        .onAppear {
          Task {
            isRemuxing = true
            guard
              let previewURL = await screenRecordService.remuxPreviewVideo(
                screenRecordEntry: screenRecordEntry)
            else {
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
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordService = recoreonServices.screenRecordService
    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    @State var screenRecordEntry = screenRecordEntries[0]
    @State var path: NavigationPath = NavigationPath()
    @StateObject var screenRecordStore = ScreenRecordStore(screenRecordService: screenRecordService)

    return NavigationStack {
      ScreenRecordPreviewView(
        screenRecordService: screenRecordService,
        screenRecordEntry: screenRecordEntry
      )
    }
  }
#endif
