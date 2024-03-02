import AVKit
import SwiftUI

struct ScreenRecordDetailViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordDetailView: View {
  @ObservedObject var recoreonServiceStore: RecoreonServiceStore
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  @StateObject var recordNoteStore: RecordNoteStore

  @Environment(\.scenePhase) private var scenePhase
//  @Environment(\.isPresented) var isPresented

  @State var isShowingRemoveConfirmation = false

  @State var isAskingNewNoteShortName = false
  @State var newNoteShortName = ""

  init(
    recoreonServiceStore: RecoreonServiceStore,
    screenRecordStore: ScreenRecordStore,
    path: Binding<NavigationPath>,
    screenRecordEntry: ScreenRecordEntry
  ) {
    self.recoreonServiceStore = recoreonServiceStore
    self.screenRecordStore = screenRecordStore
    self._path = path
    self.screenRecordEntry = screenRecordEntry
    let recordNoteStore = RecordNoteStore(
      recordNoteService: recoreonServiceStore.recordNoteService,
      screenRecordEntry: screenRecordEntry
    )
    self._recordNoteStore = StateObject(wrappedValue: recordNoteStore)
    self.isShowingRemoveConfirmation = isShowingRemoveConfirmation
  }

  func recordNoteList() -> some View {
    return Section(header: Text("Notes")) {
      ForEach(recordNoteStore.listRecordNoteEntries()) { recordNoteEntry in
        NavigationLink(value: RecordNoteEditorViewRoute(recordNoteEntry: recordNoteEntry)) {
          Button {
          } label: {
            let recordNoteShortName = recoreonServiceStore.recordNoteService.extractRecordNoteShortName(
              recordNoteEntry: recordNoteEntry)
            Label(recordNoteShortName, systemImage: "doc")
          }
        }
      }

      Button {
        isAskingNewNoteShortName = true
      } label: {
        Label("Add", systemImage: "doc.badge.plus")
      }
      .alert("Enter a new note name", isPresented: $isAskingNewNoteShortName) {
        TextField("Name", text: $newNoteShortName)
        Button {
          if !newNoteShortName.isEmpty {
            recordNoteStore.addNote(shortName: newNoteShortName)
          }
          newNoteShortName = ""
        } label: {
          Text("OK")
        }
      }
    }
  }

  var body: some View {
    Form {
      Section {
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
              title: Text("Are you sure to remove this screen record?"),
              primaryButton: .destructive(Text("OK")) {
                recoreonServiceStore.screenRecordService.removeScreenRecordAndRelatedFiles(
                  screenRecordEntry: screenRecordEntry)
                screenRecordStore.update()
                path.removeLast()
              },
              secondaryButton: .cancel()
            )
          }
        }
      }

      recordNoteList()
    }
    .navigationTitle(screenRecordEntry.url.lastPathComponent)
    .navigationDestination(for: ScreenRecordPreviewViewRoute.self) { route in
      ScreenRecordPreviewView(
        screenRecordService: recoreonServiceStore.screenRecordService,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .navigationDestination(for: ScreenRecordEncoderViewRoute.self) { route in
      ScreenRecordEncoderView(
        recoreonServiceStore: recoreonServiceStore,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .navigationDestination(for: RecordNoteEditorViewRoute.self) { route in
      RecordNoteEditorView(
        recordNoteStore: recordNoteStore,
        path: $path,
        recordNoteEntry: route.recordNoteEntry
      )
    }
  }
}

#if DEBUG
  #Preview {
    let recoreonServiceStore = previewRecoreonServiceStore
    let screenRecordService = recoreonServiceStore.screenRecordService
    let recordNoteService = recoreonServiceStore.recordNoteService
    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]
    @State var path: NavigationPath = NavigationPath()
    @StateObject var screenRecordStore = ScreenRecordStore(screenRecordService: screenRecordService)
    @StateObject var recordNoteStore = RecordNoteStore(
      recordNoteService: recordNoteService, screenRecordEntry: screenRecordEntry)

    return NavigationStack {
      ScreenRecordDetailView(
        recoreonServiceStore: recoreonServiceStore,
        screenRecordStore: screenRecordStore, path: $path, screenRecordEntry: screenRecordEntry)
    }
  }
#endif
