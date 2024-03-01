import SwiftUI

struct RecordNoteListView: View {
  let screenRecordService: ScreenRecordService
  let screenRecordEntry: ScreenRecordEntry
  @ObservedObject var recordNoteStore: RecordNoteStore

  @Environment(\.scenePhase) private var scenePhase

  @State private var isAskingNewFilename = false
  @State private var newShortName = ""

  @State private var isEditingNote = false
  @State private var editingNoteEntry = RecordNoteEntry(url: URL(string: "invalid")!, body: "")
  @State private var editingNoteBody = ""

  var body: some View {
    List {
      let recordNoteEntries = recordNoteStore.recordNoteBodies.map {
        RecordNoteEntry(url: $0.key, body: $0.value)
      }.sorted {
        $0.url.lastPathComponent.compare($1.url.lastPathComponent) == .orderedAscending
      }
      ForEach(recordNoteEntries) { noteEntry in
        Button {
          isEditingNote = true
          editingNoteEntry = noteEntry
          editingNoteBody = noteEntry.body
        } label: {
          Label(noteEntry.shortName, systemImage: "doc")
        }
      }
      Button {
        isAskingNewFilename = true
      } label: {
        Label("Add", systemImage: "doc.badge.plus")
      }
      .alert("Enter a new note name", isPresented: $isAskingNewFilename) {
        TextField("Name", text: $newShortName)
        Button {
          if !newShortName.isEmpty {
            recordNoteStore.addNote(shortName: newShortName)
          }
          newShortName = ""
        } label: {
          Text("OK")
        }
      }
    }
    .sheet(isPresented: $isEditingNote) {
      Form {
        HStack {
          Text("Filename:")
          Text(editingNoteEntry.url.lastPathComponent)
        }
        Button {
          recordNoteStore.deleteNote(recordNoteURL: editingNoteEntry.url)
          isEditingNote = false
        } label: {
          Text("Remove")
        }
        TextField("Enter the note text here.", text: $editingNoteBody, axis: .vertical)
      }
    }
    .onChange(of: editingNoteBody) { _ in
      recordNoteStore.putNote(recordNoteURL: editingNoteEntry.url, body: editingNoteBody)
    }
    .onChange(of: isEditingNote) { newValue in
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
    let screenRecordService = ScreenRecordServiceMock()
    let recordNoteService = RecordNoteServiceMock()
    let screenRecordURLs = screenRecordService.listScreenRecordURLs()
    let screenRecordEntries = screenRecordService.listScreenRecordEntries(screenRecordURLs: screenRecordURLs)
    let screenRecordEntry = screenRecordEntries[0]
    @StateObject var recordNoteStore = RecordNoteStore(recordNoteService, screenRecordEntry)

    return Form {
      RecordNoteListView(
        screenRecordService: screenRecordService,
        screenRecordEntry: screenRecordEntry,
        recordNoteStore: recordNoteStore
      )
    }
  }
#endif
