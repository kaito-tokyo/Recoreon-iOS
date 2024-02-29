import AVKit
import SwiftUI

private func getThumbnailUnavailableImage() -> UIImage {
  let config = UIImage.SymbolConfiguration(font: .systemFont(ofSize: 200))
  return UIImage(systemName: "xmark.circle", withConfiguration: config)!
}

struct ScreenRecordDetailViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordDetailView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

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
          guard let previewURL = await screenRecordService.remux(screenRecordEntry.url) else {
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
            var imageRef = screenRecordService.getThumbnailImage(screenRecordEntry.url)
            if imageRef == nil {
              await screenRecordService.generateThumbnail(screenRecordEntry.url)
              imageRef = screenRecordService.getThumbnailImage(screenRecordEntry.url)
            }
            if let image = imageRef {
              thumbnailImage = image
            } else {
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
        value: ScreenRecordEncoderViewRoute(screenRecordEntry: screenRecordEntry)
      ) {
        Button {
        } label: {
          Label("Encode", systemImage: "film")
        }
      }
      ShareLink(item: screenRecordEntry.url)
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
            screenRecordService.removeThumbnail(screenRecordEntry)
            screenRecordService.removePreviewVideo(screenRecordEntry)
            screenRecordService.removeScreenRecord(screenRecordEntry)
            screenRecordService.removeEncodedVideos(screenRecordEntry)
            screenRecordStore.update()
            path.removeLast()
          },
          secondaryButton: .cancel()
        )
      }
    }
    .navigationDestination(for: ScreenRecordEncoderViewRoute.self) { route in
      ScreenRecordEncoderView(
        screenRecordService: screenRecordService,
        screenRecordEntry: route.screenRecordEntry,
        screenRecordThumbnail: thumbnailImage
      )
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
      ScreenRecordDetailView(
        screenRecordService: service,
        screenRecordStore: store,
        path: $path,
        screenRecordEntry: selectedEntry
      )
    }
  }
#endif
