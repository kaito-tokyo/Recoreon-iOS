import AVKit
import ReplayKit
import SwiftUI

let byteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useMB, .useGB]
  return bcf
}()

struct RecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore
  @Binding var path: NavigationPath

  @State private var editMode: EditMode = .inactive
  @State private var selection = Set<URL>()
  @State private var isRemoveConfirmationPresented: Bool = false

  func recordedVideoEntry(_ entry: RecordedVideoEntry) -> some View {
    return HStack {
      if editMode.isEditing {
        if selection.contains(entry.url) {
          Image(systemName: "checkmark.circle")
            .foregroundColor(.green)
        } else {
          Image(systemName: "circle")
        }
      }
      VStack {
        HStack {
          Text(entry.url.lastPathComponent)
          Spacer()
        }
        HStack {
          Text(entry.creationDate.formatted())
          Text(byteCountFormatter.string(fromByteCount: Int64(entry.size)))
          Spacer()
        }
      }
    }
  }

  func recordedVideoList() -> some View {
    return List {
      ForEach(recordedVideoStore.recordedVideoEntries) { entry in
        let detailViewRoute = RecordedVideoDetailViewRoute(recordedVideoEntry: entry)
        if editMode.isEditing {
          Button {
            if selection.contains(entry.url) {
              selection.remove(entry.url)
            } else {
              selection.insert(entry.url)
            }
          } label: {
            recordedVideoEntry(entry)
          }
          .foregroundStyle(.foreground)
        } else {
          NavigationLink(value: detailViewRoute) {
            recordedVideoEntry(entry)
          }
        }
      }
    }
  }

  func shareLinkButton() -> some View {
    return VStack {
      Spacer()
      HStack {
        Spacer()
        ShareLink(
          items: Array(selection),
          label: {
            Image(systemName: "square.and.arrow.up")
              .resizable()
              .scaledToFill()
              .frame(width: 32, height: 32)
              .tint(Color.white)
              .padding(.all, 20)
              .background(selection.isEmpty ? Color.gray : Color.blue)
              .clipShape(Circle())
          }
        )
        .disabled(selection.isEmpty)
        Button {
          isRemoveConfirmationPresented = true
        } label: {
          Image(systemName: "trash")
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .tint(Color.white)
            .padding(.all, 20)
            .background(selection.isEmpty ? Color.gray : Color.red)
            .clipShape(Circle())
        }
        .disabled(selection.isEmpty)
        .padding(.trailing, 10)
        .padding(.bottom, 10)
      }
      .alert(isPresented: $isRemoveConfirmationPresented) {
        Alert(
          title: Text("Are you sure to remove all of the selected videos?"),
          primaryButton: .destructive(Text("OK")) {
            let entries = selection.compactMap { entryURL in
              recordedVideoStore.recordedVideoEntries.first { entry in
                entry.url == entryURL
              }
            }
            for entry in entries {
              recordedVideoService.removeThumbnail(entry)
              recordedVideoService.removePreviewVideo(entry)
              recordedVideoService.removeRecordedVideo(entry)
              recordedVideoService.removeEncodedVideos(entry)
            }
            recordedVideoStore.update()
          },
          secondaryButton: .cancel()
        )
      }
    }
  }

  var body: some View {
    ZStack {
      recordedVideoList()
      shareLinkButton()
    }
    .navigationTitle("List")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: RecordedVideoDetailViewRoute.self) { route in
      RecordedVideoDetailView(
        recordedVideoService: recordedVideoService,
        recordedVideoStore: recordedVideoStore,
        path: $path,
        recordedVideoEntry: route.recordedVideoEntry
      )
    }
    .toolbar {
      EditButton()
    }
    .environment(\.editMode, $editMode)
    .onChange(of: editMode) { newValue in
      if newValue == .inactive {
        selection.removeAll()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    @State var entries = service.listRecordedVideoEntries()
    @State var path = NavigationPath()
    @StateObject var store = RecordedVideoStore(recordedVideoService: service)

    return NavigationStack {
      RecordedVideoListView(
        recordedVideoService: service,
        recordedVideoStore: store,
        path: $path
      )
    }
  }
#endif
