import SwiftUI

struct RecordNoteListView: View {
  let screenRecordService: ScreenRecordService
  let screenRecordEntry: ScreenRecordEntry
  @ObservedObject var recordNoteStore: RecordNoteStore

  @State var isAskingNewFilename = false
  @State var newFilename = ""

  @State var isEditingNote = false
  @State var editingNoteEntry = RecordNoteEntry(url: URL(string: "invalid")!, body: "")
  @State var editingNoteBody = ""

  var body: some View {
    List {
      let recordNoteEntries = recordNoteStore.recordNoteBodies.map {
        RecordNoteEntry(url: $0.key, body: $0.value)
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
        TextField("Enter a new note name.", text: $newFilename)
        Button {

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

        } label: {
          Text("Save")
        }
        Button {

        } label: {
          Text("Rename")
        }
        TextField("Enter the note text here.", text: $editingNoteBody, axis: .vertical)
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = ScreenRecordServiceMock()
    let screenRecordEntries = service.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]
    @StateObject var recordNoteStore = RecordNoteStore(service, screenRecordEntry)

    return Form {
      RecordNoteListView(
        screenRecordService: service,
        screenRecordEntry: screenRecordEntry,
        recordNoteStore: recordNoteStore
      )
    }
  }
#endif
