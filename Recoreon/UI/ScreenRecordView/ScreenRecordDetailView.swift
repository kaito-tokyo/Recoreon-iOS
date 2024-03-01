import AVKit
import SwiftUI

struct ScreenRecordDetailViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordDetailView: View {
  let screenRecordService: ScreenRecordService
  let recordNoteService: RecordNoteService

  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  @StateObject var recordNoteStore: RecordNoteStore

  @State var isShowingRemoveConfirmation = false

  init(
    screenRecordService: ScreenRecordService, recordNoteService: RecordNoteService,
    screenRecordStore: ScreenRecordStore, path: Binding<NavigationPath>,
    screenRecordEntry: ScreenRecordEntry
  ) {
    self.screenRecordService = screenRecordService
    self.recordNoteService = recordNoteService
    self.screenRecordStore = screenRecordStore
    self._path = path
    self.screenRecordEntry = screenRecordEntry
    let recordNoteStore = RecordNoteStore(
      recordNoteService: recordNoteService, screenRecordEntry: screenRecordEntry)
    self._recordNoteStore = StateObject(wrappedValue: recordNoteStore)
    self.isShowingRemoveConfirmation = isShowingRemoveConfirmation
  }

  var body: some View {
    let encodeService = screenRecordService.createEncodeService()
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
                screenRecordService.removeScreenRecordAndRelatedFiles(
                  screenRecordURL: screenRecordEntry.url)
                screenRecordStore.update()
                path.removeLast()
              },
              secondaryButton: .cancel()
            )
          }
        }
      }
      Section(header: Text("Notes")) {
        RecordNoteListView(recordNoteStore: recordNoteStore)
      }
    }
    .navigationDestination(for: ScreenRecordPreviewViewRoute.self) { route in
      ScreenRecordPreviewView(
        screenRecordService: screenRecordService,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .navigationDestination(for: ScreenRecordEncoderViewRoute.self) { route in
      ScreenRecordEncoderView(
        encodeService: encodeService, screenRecordEntry: route.screenRecordEntry)
    }
  }
}

#if DEBUG
  #Preview {
    let screenRecordService = ScreenRecordServiceMock()
    let recordNoteService = screenRecordService.createRecordNoteService()
    let screenRecordURLs = screenRecordService.listScreenRecordURLs()
    let screenRecordEntries = screenRecordService.listScreenRecordEntries(
      screenRecordURLs: screenRecordURLs)
    let screenRecordEntry = screenRecordEntries[0]
    @State var path: NavigationPath = NavigationPath()
    @StateObject var screenRecordStore = ScreenRecordStore(screenRecordService: screenRecordService)
    @StateObject var recordNoteStore = RecordNoteStore(
      recordNoteService: recordNoteService, screenRecordEntry: screenRecordEntry)

    return NavigationStack {
      ScreenRecordDetailView(
        screenRecordService: screenRecordService, recordNoteService: recordNoteService,
        screenRecordStore: screenRecordStore, path: $path, screenRecordEntry: screenRecordEntry)
    }
  }
#endif
