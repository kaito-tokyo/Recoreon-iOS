import AVKit
import ReplayKit
import SwiftUI

struct RecordedVideoAdvancedView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @Binding var recordedVideoEntries: [RecordedVideoEntry]

  @State var player = AVPlayer()
  @State var isPresentedPlayer: Bool = false
  @State var isPresentedRemuxing: Bool = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(recordedVideoEntries) { entry in
          NavigationLink {
            Button {
              Task {
                isPresentedRemuxing = true
                guard let previewURL = await recordedVideoManipulator.remux(entry.url) else {
                  return
                }
                player.replaceCurrentItem(with: AVPlayerItem(url: previewURL))
                isPresentedRemuxing = false
                isPresentedPlayer = true
              }
            } label: {
              ZStack {
                Image(uiImage: entry.uiImage).resizable().scaledToFit()
                Image(systemName: "play.fill").font(.system(size: 200))
                if isPresentedRemuxing {
                  ProgressView().tint(.white).scaleEffect(CGSize(width: 10, height: 10))
                }
              }
            }.disabled(isPresentedRemuxing)
          } label: {
            VStack {
              HStack {
                Text(entry.url.lastPathComponent)
                Spacer()
              }
              HStack {
                Text(Date().formatted())
                Text("1GB")
                Spacer()
              }
            }
          }.sheet(isPresented: $isPresentedPlayer) {
            GeometryReader { geometry in
              VideoPlayer(player: player).onAppear {
                player.play()
              }.onDisappear {
                player.pause()
                isPresentedRemuxing = false
              }.frame(height: geometry.size.height)
            }
          }
        }
      }
      .navigationTitle("List of recorded videos")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  let recordedVideoManipulator = RecordedVideoManipulatorMock()
  @State var recordedVideoEntries = recordedVideoManipulator.listVideoEntries()

  return RecordedVideoAdvancedView(
    recordedVideoManipulator: RecordedVideoManipulatorMock(),
    recordedVideoEntries: $recordedVideoEntries)
}
