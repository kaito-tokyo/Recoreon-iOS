import AVKit
import SwiftUI

private func getThumbnailUnavailableImage() -> UIImage {
  let config = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 200))
  return UIImage(systemName: "xmark.circle", withConfiguration: config)!
}

struct AdvancedRecordedVideoDetailViewRoute: Hashable {
  let recordedVideoEntry: RecordedVideoEntry
}

struct AdvancedRecordedVideoDetailView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore
  @Binding var path: NavigationPath
  let recordedVideoEntry: RecordedVideoEntry

  let player = AVPlayer()

  @State var isVideoPlayerPresented: Bool = false
  @State var isRemuxing: Bool = false
  @State var isRemuxingFailed: Bool = false

  @State var thumbnailImage: UIImage = getThumbnailUnavailableImage()

  @State var isShowingRemoveConfirmation = false

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
      NavigationLink(
        value: AdvencedVideoEncoderViewRoute(recordedVideoEntry: recordedVideoEntry)
      ) {
        Button {
        } label: {
          Label("Encode", systemImage: "film")
        }
      }
      ShareLink(item: recordedVideoEntry.url)
      Button {
        isShowingRemoveConfirmation = true
      } label: {
        Label {
          Text("Remove")
        } icon: {
          Image(systemName: "trash")
        }
      }.alert(isPresented: $isShowingRemoveConfirmation) {
        Alert(
          title: Text("Are you sure to remove this video?"),
          primaryButton: .destructive(Text("OK")) {
            recordedVideoService.removeThumbnail(recordedVideoEntry: recordedVideoEntry)
            recordedVideoService.removePreviewVideo(recordedVideoEntry: recordedVideoEntry)
            recordedVideoService.removeRecordedVideo(recordedVideoEntry: recordedVideoEntry)
            recordedVideoService.removeEncodedVideos(recordedVideoEntry: recordedVideoEntry)
            recordedVideoStore.update()
            path.removeLast()
          },
          secondaryButton: .cancel()
        )
      }
    }
    .navigationDestination(for: AdvencedVideoEncoderViewRoute.self) { route in
      AdvancedVideoEncoderView(
        recordedVideoService: recordedVideoService,
        recordedVideoEntry: route.recordedVideoEntry,
        recordedVideoThumbnail: thumbnailImage
      )
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    let entries = service.listRecordedVideoEntries()
    @State var selectedEntry = entries.first!
    @State var path: NavigationPath = NavigationPath()
    @StateObject var store = RecordedVideoStore(recordedVideoService: service)

    return NavigationStack {
      AdvancedRecordedVideoDetailView(
        recordedVideoService: service,
        recordedVideoStore: store,
        path: $path,
        recordedVideoEntry: selectedEntry
      )
    }
  }
#endif
