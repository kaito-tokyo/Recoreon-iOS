import SwiftUI

struct RecordNoteListView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  @State var isAskingNewFilename = false
  @State var newFilename = ""

  @State var isEditingNote = false
  @State var editingNoteEntry = ScreenRecordNoteEntry(url: URL(string: "invalid")!, body: "")
  @State var editingNoteBody = ""

  var body: some View {
    List {
      ForEach(screenRecordEntry.noteEntries) { noteEntry in
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
    let entries = service.listScreenRecordEntries()
    @State var selectedEntry = entries.first!
    @State var path: NavigationPath = NavigationPath()
    @StateObject var store = ScreenRecordStore(screenRecordService: service)

    return Form {
      RecordNoteListView(
        screenRecordService: service,
        screenRecordStore: store,
        path: $path,
        screenRecordEntry: selectedEntry
      )
    }
  }
#endif
