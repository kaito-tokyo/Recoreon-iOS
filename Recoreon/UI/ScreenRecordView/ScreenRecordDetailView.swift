import AVKit
import SwiftUI

struct ScreenRecordDetailViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordDetailView: View {
  let recoreonServices: RecoreonServices

  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  @StateObject var recordNoteStore: RecordNoteStore

  @Environment(\.scenePhase) var scenePhase
  @Environment(\.isPresented) var isPresented

  @State var isShowingRemoveConfirmation = false

  @State var editingRecordSummaryBody: String = ""

  @State var isAskingNewNoteShortName = false
  @State var newNoteShortName = ""

  let recordNoteService: RecordNoteService

  init(
    recoreonServices: RecoreonServices,
    screenRecordStore: ScreenRecordStore,
    path: Binding<NavigationPath>,
    screenRecordEntry: ScreenRecordEntry
  ) {
    self.recoreonServices = recoreonServices
    self.screenRecordStore = screenRecordStore
    _path = path
    self.screenRecordEntry = screenRecordEntry
    let recordNoteStore = RecordNoteStore(
      recordNoteService: recoreonServices.recordNoteService,
      screenRecordEntry: screenRecordEntry
    )
    _recordNoteStore = StateObject(wrappedValue: recordNoteStore)

    let recordSummaryEntry = recoreonServices.recordNoteService.readRecordSummaryEntry(
      screenRecordEntry: screenRecordEntry)
    _editingRecordSummaryBody = State(initialValue: recordSummaryEntry.body)

    recordNoteService = recoreonServices.recordNoteService
  }

  func recordNoteList() -> some View {
    return Section(header: Text("Notes")) {
      TextField("Enter the summary...", text: $editingRecordSummaryBody)
        .onChange(of: editingRecordSummaryBody) { newValue in
          let recordSummaryURL = recoreonServices.recordNoteService.generateRecordSummaryURL(
            screenRecordEntry: screenRecordEntry
          )
          recordNoteStore.putNote(recordNoteURL: recordSummaryURL, body: newValue)
        }

      ForEach(recordNoteStore.listGeneralRecordNoteEntries()) { recordNoteEntry in
        NavigationLink(value: RecordNoteEditorViewRoute(recordNoteEntry: recordNoteEntry)) {
          Button {
          } label: {
            let recordNoteShortName = recoreonServices.recordNoteService.extractRecordNoteShortName(
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
    .onChange(of: scenePhase) { newValue in
      if scenePhase == .active && newValue == .inactive {
        recordNoteStore.saveAllNotes()
      }
    }
    .onChange(of: isPresented) { newValue in
      if !newValue {
        recordNoteStore.saveAllNotes()
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
                recoreonServices.screenRecordService.removeScreenRecordAndRelatedFiles(
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
        recoreonServices: recoreonServices,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .navigationDestination(for: ScreenRecordEncoderViewRoute.self) { route in
      ScreenRecordEncoderView(
        recoreonServices: recoreonServices, screenRecordEntry: route.screenRecordEntry)
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
  struct ScreenRecordDetailViewContainer: View {
    let recoreonServices: RecoreonServices
    @StateObject var screenRecordStore: ScreenRecordStore
    @State var path: NavigationPath
    let screenRecordEntry: ScreenRecordEntry

    init(
      recoreonServices: RecoreonServices,
      screenRecordStore: ScreenRecordStore,
      path: NavigationPath,
      screenRecordEntry: ScreenRecordEntry
    ) {
      self.recoreonServices = recoreonServices
      _screenRecordStore = StateObject(wrappedValue: screenRecordStore)
      _path = State(initialValue: path)
      self.screenRecordEntry = screenRecordEntry
    }

    var body: some View {
      TabView {
        NavigationStack(path: $path) {
          ScreenRecordDetailView(
            recoreonServices: recoreonServices,
            screenRecordStore: screenRecordStore,
            path: $path,
            screenRecordEntry: screenRecordEntry
          )
        }
      }
    }
  }

  #Preview {
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordService = recoreonServices.screenRecordService
    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]
    let path: NavigationPath = NavigationPath()
    let screenRecordStore = ScreenRecordStore(
      screenRecordService: screenRecordService
    )

    return ScreenRecordDetailViewContainer(
      recoreonServices: recoreonServices,
      screenRecordStore: screenRecordStore,
      path: path,
      screenRecordEntry: screenRecordEntry
    )
  }
#endif
