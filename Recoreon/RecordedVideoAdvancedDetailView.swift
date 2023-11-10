import AVKit
import SwiftUI

struct RecordedVideoAdvancedDetailView: View {
  let recordedVideoManipulator: RecordedVideoManipulator
  @State var recordedVideoEntry: RecordedVideoEntry
  @State var recordedVideoURL: URL

  let player = AVPlayer()

  @State var isVideoPlayerPresented: Bool = false
  @State var isRemuxing: Bool = false
  @State var isRemuxingFailed: Bool = false

  var body: some View {
    Button {
      Task {
        isRemuxing = true
        guard let previewURL = await recordedVideoManipulator.remux(recordedVideoEntry.url) else {
          isRemuxingFailed = true
          isRemuxing = false
          return
        }
        player.replaceCurrentItem(with: AVPlayerItem(url: previewURL))
        isVideoPlayerPresented = true
        isRemuxing = false
      }
    } label: {
      ZStack {
        Image(uiImage: recordedVideoEntry.uiImage).resizable().scaledToFit()
        Image(systemName: "play.fill").font(.system(size: 200))
        if isRemuxing {
          ProgressView()
            .tint(.white)
            .scaleEffect(CGSize(width: 10, height: 10))
        }
      }
    }.disabled(isRemuxing)
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          Button {

          } label: {
            Text("aaa")
          }
        }
      }
      .sheet(isPresented: $isVideoPlayerPresented) {
        GeometryReader { geometry in
          VideoPlayer(player: player)
            .onAppear {
              player.play()
            }
            .onDisappear {
              player.pause()
            }
            .frame(height: geometry.size.height)
        }
      }
  }
}

#if DEBUG
  #Preview {
    let recordedVideoManipulator = RecordedVideoManipulatorMock()
    let recordedVideoEntries = recordedVideoManipulator.listVideoEntries()
    let recordedVideoURLs = recordedVideoManipulator.listRecordedVideoURLs()
    @State var recordedVideoEntry = recordedVideoEntries.first!
    @State var recordedVideoURL = recordedVideoURLs.first!

    return RecordedVideoAdvancedDetailView(
      recordedVideoManipulator: recordedVideoManipulator, recordedVideoEntry: recordedVideoEntry,
      recordedVideoURL: recordedVideoURL)
  }
#endif
