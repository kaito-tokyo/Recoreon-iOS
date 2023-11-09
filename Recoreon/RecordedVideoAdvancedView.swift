import ReplayKit
import SwiftUI
import AVKit

struct RecordedVideoAdvancedView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @Binding var recordedVideoEntries: [RecordedVideoEntry]

  @State var player = AVPlayer()
  @State var isPresentedPlayer: Bool = false

  var body: some View {
    NavigationStack {
      List {
        ForEach(recordedVideoEntries) { entry in
          NavigationLink {
            Button {
              let previewURL = RecoreonPaths().encodedVideosDir.appending(path: "a.mp4", directoryHint: .notDirectory)
              FFmpegKit.execute(withArguments: [
                "-y",
                "-i",
                entry.url.path(),
                "-c:v",
                "copy",
                "-c:a",
                "copy",
                previewURL.path()
              ])
              player.replaceCurrentItem(with: AVPlayerItem(url: previewURL))
              isPresentedPlayer = true
            } label: {
              ZStack {
                Image(uiImage: entry.uiImage).resizable().scaledToFit()
                Image(systemName: "play.fill").font(.system(size: 200))
              }
            }
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                  player.play()
                })
              }.onDisappear{
                player.pause()
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

  return RecordedVideoAdvancedView(recordedVideoManipulator: RecordedVideoManipulatorMock(), recordedVideoEntries: $recordedVideoEntries)
}
