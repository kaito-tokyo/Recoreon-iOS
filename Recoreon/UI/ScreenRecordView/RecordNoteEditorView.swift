import SwiftUI

struct RecordNoteEditorViewRoute: Hashable {
  let recordNoteEntry: RecordNoteEntry
}

struct RecordNoteEditorView: View {
  @ObservedObject var recordNoteStore: RecordNoteStore
  @Binding var path: NavigationPath
  let recordNoteEntry: RecordNoteEntry

  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.isPresented) var isPresented

  @State private var editingNoteBody: String

  init(
    recordNoteStore: RecordNoteStore,
    path: Binding<NavigationPath>,
    recordNoteEntry: RecordNoteEntry
  ) {
    self.recordNoteStore = recordNoteStore
    _path = path
    self.recordNoteEntry = recordNoteEntry
    _editingNoteBody = State(initialValue: recordNoteEntry.body)
  }

  var body: some View {
    Form {
      TextField("Enter the note text here", text: $editingNoteBody, axis: .vertical)
    }
    .navigationTitle(recordNoteEntry.filename)
    .onChange(of: editingNoteBody) { _ in
      recordNoteStore.putNote(recordNoteURL: recordNoteEntry.url, body: editingNoteBody)
    }
    .onChange(of: isPresented) { newValue in
      if newValue == false {
        recordNoteStore.saveAllNotes()
      }
    }
    .onChange(of: scenePhase) { newValue in
      if scenePhase == .active && newValue == .inactive {
        recordNoteStore.saveAllNotes()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordService = recoreonServices.screenRecordService
    let recordNoteService = recoreonServices.recordNoteService

    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]

    @StateObject var recordNoteStore = RecordNoteStore(
      recordNoteService: recordNoteService, screenRecordEntry: screenRecordEntry)

    @State var path = NavigationPath()

    let recordNoteEntries = recordNoteService.listRecordNoteEntries(
      screenRecordEntry: screenRecordEntry)
    let recordNoteEntry = recordNoteEntries[0]

    return NavigationStack {
      RecordNoteEditorView(
        recordNoteStore: recordNoteStore,
        path: $path,
        recordNoteEntry: recordNoteEntry
      )
    }
  }
#endif
