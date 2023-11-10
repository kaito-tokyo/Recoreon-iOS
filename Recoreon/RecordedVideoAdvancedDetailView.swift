import AVKit
import SwiftUI

private func getThumbnailUnavailableImage() -> UIImage {
  let config = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 200))
  return UIImage(systemName: "xmark.circle", withConfiguration: config)!
}

struct RecordedVideoAdvancedDetailView: View {
  let recordedVideoService: RecordedVideoService
  @State var recordedVideoEntry: RecordedVideoEntry

  let player = AVPlayer()

  @State var isVideoPlayerPresented: Bool = false
  @State var isRemuxing: Bool = false
  @State var isRemuxingFailed: Bool = false

  @State var thumbnailImage: UIImage = getThumbnailUnavailableImage()

  var body: some View {
    VStack {
      Button {
        Task {
          isRemuxing = true
          guard let previewURL = await recordedVideoService.remux(recordedVideoEntry.url) else {
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
          Image(
            uiImage: thumbnailImage
          ).resizable().scaledToFit()
          Image(systemName: "play.fill").font(.system(size: 200))
          if isRemuxing {
            ProgressView()
              .tint(.white)
              .scaleEffect(CGSize(width: 10, height: 10))
          }
        }
        .onAppear {
          Task {
            var imageRef = recordedVideoService.getThumbnailImage(recordedVideoEntry.url)
            if imageRef == nil {
              await recordedVideoService.generateThumbnail(recordedVideoEntry.url)
              imageRef = recordedVideoService.getThumbnailImage(recordedVideoEntry.url)
            }
            if let image = imageRef {
              thumbnailImage = image
            } else {
              let config = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 200))
              thumbnailImage = getThumbnailUnavailableImage()
            }
          }
        }
      }
      .disabled(isRemuxing)
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
    List {
      NavigationLink {
        AdvancedVideoEncoderView(
          recordedVideoService: recordedVideoService,
          recordedVideoEntry: recordedVideoEntry,
          recordedVideoThumbnail: thumbnailImage
        )
      } label: {
        Button {

        } label: {
          Label("Encode", systemImage: "film")
        }
      }
      Button {
      } label: {
        Label {
          Text("Remove")
        } icon: {
          Image(systemName: "trash")
        }
      }
      ShareLink(item: recordedVideoEntry.url)
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    let entries = service.listRecordedVideoEntries()
    @State var selectedEntry = entries.first!

    return RecordedVideoAdvancedDetailView(
      recordedVideoService: service,
      recordedVideoEntry: selectedEntry
    )
  }
#endif
