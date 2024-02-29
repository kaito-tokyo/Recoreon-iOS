import AVKit
import SwiftUI

struct ScreenRecordDetailViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordDetailView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  @State var isShowingRemoveConfirmation = false

  var body: some View {
    let recordNoteEntries = screenRecordService.listRecordNote(screenRecordEntry)
    Text(screenRecordEntry.url.lastPathComponent)
    Form {
      Section(header: Text("Operations")) {
        List {
          NavigationLink(
            value: ScreenRecordPreviewViewRoute(screenRecordEntry: screenRecordEntry)
          ) {
            Button {
            } label: {
              Label("Preview", systemImage: "play")
            }
          }
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
      }
      Section(header: Text("Notes")) {
        RecordNoteListView(
          screenRecordService: screenRecordService,
          screenRecordEntry: screenRecordEntry,
          recordNoteEntries: recordNoteEntries
        )
      }
    }
    .navigationDestination(for: ScreenRecordPreviewViewRoute.self) { route in
      ScreenRecordPreviewView(
        screenRecordService: screenRecordService, screenRecordStore: screenRecordStore, path: $path,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .navigationDestination(for: ScreenRecordEncoderViewRoute.self) { route in
      ScreenRecordEncoderView(
        screenRecordService: screenRecordService,
        screenRecordEntry: route.screenRecordEntry
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
