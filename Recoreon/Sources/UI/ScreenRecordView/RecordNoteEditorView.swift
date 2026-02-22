import SwiftUI

struct RecordNoteEditorViewRoute: Hashable {
  let recordNoteEntry: RecordNoteEntry
}

struct RecordNoteEditorView: View {
  @Binding private var path: NavigationPath
  @ObservedObject private var recordNoteStore: RecordNoteStore
  private let recordNoteEntry: RecordNoteEntry

  @State private var editingNoteBody: String

  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.isPresented) private var isPresented

  init(
    path: Binding<NavigationPath>,
    recordNoteStore: RecordNoteStore,
    recordNoteEntry: RecordNoteEntry
  ) {
    self._path = path
    self.recordNoteStore = recordNoteStore
    self.recordNoteEntry = recordNoteEntry
    _editingNoteBody = State(initialValue: recordNoteEntry.body)
  }

  var body: some View {
    Form {
      TextField("Enter the note text here...", text: $editingNoteBody, axis: .vertical)
    }
    .navigationTitle(recordNoteEntry.url.lastPathComponent)
    .onChange(of: editingNoteBody) { _ in
      recordNoteStore.putNote(recordNoteURL: recordNoteEntry.url, body: editingNoteBody)
    }
    .onChange(of: scenePhase) { newValue in
      if scenePhase == .active && newValue == .inactive {
        recordNoteStore.saveAllNotes()
      }
    }
    .onChange(of: isPresented) { newValue in
      if newValue == false {
        recordNoteStore.saveAllNotes()
      }
    }
    .onChange(of: path) { _ in
      recordNoteStore.saveAllNotes()
    }
  }
}

#if DEBUG
  struct RecordNoteEditorViewContainer: View {
    @StateObject var recordNoteStore: RecordNoteStore
    let recordNoteEntry: RecordNoteEntry

    @State var path = NavigationPath()

    init(
      recordNoteStore: RecordNoteStore,
      recordNoteEntry: RecordNoteEntry
    ) {
      self._recordNoteStore = StateObject(wrappedValue: recordNoteStore)
      self.recordNoteEntry = recordNoteEntry
    }

    var body: some View {
      TabView {
        NavigationStack(path: $path) {
          RecordNoteEditorView(
            path: $path,
            recordNoteStore: recordNoteStore,
            recordNoteEntry: recordNoteEntry
          )
        }
      }
    }
  }

  #Preview("Record01-1") {
    let recoreonServices = PreviewRecoreonServices()
    recoreonServices.deployAllAssets()

    let screenRecordService = recoreonServices.screenRecordService
    let recordNoteService = recoreonServices.recordNoteService

    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]

    let recordNoteStore = RecordNoteStore(
      recordNoteService: recordNoteService, screenRecordEntry: screenRecordEntry)

    let recordNoteEntries = recordNoteService.listRecordNoteEntries(
      screenRecordEntry: screenRecordEntry)
    let recordNoteEntry = recordNoteEntries[0]

    return RecordNoteEditorViewContainer(
      recordNoteStore: recordNoteStore,
      recordNoteEntry: recordNoteEntry
    )
  }

  #Preview("Record01-2") {
    let recoreonServices = PreviewRecoreonServices()
    recoreonServices.deployAllAssets()

    let screenRecordService = recoreonServices.screenRecordService
    let recordNoteService = recoreonServices.recordNoteService

    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]

    let recordNoteStore = RecordNoteStore(
      recordNoteService: recordNoteService, screenRecordEntry: screenRecordEntry)

    let recordNoteEntries = recordNoteService.listRecordNoteEntries(
      screenRecordEntry: screenRecordEntry)
    let recordNoteEntry = recordNoteEntries[1]

    return RecordNoteEditorViewContainer(
      recordNoteStore: recordNoteStore,
      recordNoteEntry: recordNoteEntry
    )
  }
#endif
