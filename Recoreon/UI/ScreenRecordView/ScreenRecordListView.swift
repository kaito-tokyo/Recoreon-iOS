import AVKit
import ReplayKit
import SwiftUI

let byteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useMB, .useGB]
  return bcf
}()

struct ScreenRecordListView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath

  @State private var editMode: EditMode = .inactive
  @State private var selection = Set<URL>()
  @State private var isRemoveConfirmationPresented: Bool = false

  func screenRecordEntry(_ entry: ScreenRecordEntry) -> some View {
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

  func screenRecordList() -> some View {
    return List {
      ForEach(screenRecordStore.screenRecordEntries) { entry in
        let detailViewRoute = ScreenRecordDetailViewRoute(screenRecordEntry: entry)
        if editMode.isEditing {
          Button {
            if selection.contains(entry.url) {
              selection.remove(entry.url)
            } else {
              selection.insert(entry.url)
            }
          } label: {
            screenRecordEntry(entry)
          }
          .foregroundStyle(.foreground)
        } else {
          NavigationLink(value: detailViewRoute) {
            screenRecordEntry(entry)
          }
        }
      }
    }
  }

  func shareLinkButton() -> some View {
    let shareURLs = selection.flatMap { screenRecordURL in

      let recordNoteURLs = screenRecordService.listRecordNoteURLs(screenRecordURL: screenRecordURL)
      return [screenRecordURL] + recordNoteURLs
    }
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
              screenRecordStore.screenRecordEntries.first { entry in
                entry.url == entryURL
              }
            }
            for entry in entries {
              screenRecordService.removeThumbnail(entry)
              screenRecordService.removePreviewVideo(entry)
              screenRecordService.removeScreenRecord(entry)
              screenRecordService.removeEncodedVideos(entry)
            }
            screenRecordStore.update()
          },
          secondaryButton: .cancel()
        )
      }
    }
  }

  var body: some View {
    ZStack {
      screenRecordList()
      shareLinkButton()
    }
    .navigationTitle("List")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: ScreenRecordDetailViewRoute.self) { route in
      ScreenRecordDetailView(
        screenRecordService: screenRecordService,
        screenRecordStore: screenRecordStore,
        path: $path,
        screenRecordEntry: route.screenRecordEntry
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
    let service = ScreenRecordServiceMock()
    @State var entries = service.listScreenRecordEntries()
    @State var path = NavigationPath()
    @StateObject var store = ScreenRecordStore(screenRecordService: service)

    return NavigationStack {
      ScreenRecordListView(
        screenRecordService: service,
        screenRecordStore: store,
        path: $path
      )
    }
  }
#endif
