import AVKit
import SwiftUI

struct ScreenRecordPreviewViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordPreviewView: View {
  let recoreonServices: RecoreonServices
  let screenRecordEntry: ScreenRecordEntry

  @State var player = AVPlayer()

  @State var isRemuxing: Bool = false

  @State var isShowingRemoveConfirmation = false

  var body: some View {
    ZStack {
      VideoPlayer(player: player)
        .onAppear {
          Task {
            isRemuxing = true
            guard
              let previewURL = await recoreonServices.screenRecordService.remuxPreviewVideo(
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
    let screenRecordService = recoreonServices.screenRecordService
    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]

    return ScreenRecordPreviewViewContainer(
      recoreonServices: recoreonServices,
      screenRecordEntry: screenRecordEntry
    )
  }
#endif
