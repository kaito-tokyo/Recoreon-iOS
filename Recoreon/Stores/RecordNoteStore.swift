import SwiftUI

class RecordNoteStore: ObservableObject {
  let recordNoteService: RecordNoteService
  let screenRecordEntry: ScreenRecordEntry

  @Published var recordNoteBodies: [URL: String] = [:]

  init(recordNoteService: RecordNoteService, screenRecordEntry: ScreenRecordEntry) {
    self.recordNoteService = recordNoteService
    self.screenRecordEntry = screenRecordEntry
    let recordNoteEntries = recordNoteService.listRecordNoteEntries(
      screenRecordEntry: screenRecordEntry)
    self.recordNoteBodies = Dictionary(
      uniqueKeysWithValues: recordNoteEntries.map {
        ($0.url, $0.body)
      })
  }

  func listRecordNoteEntries() -> [RecordNoteEntry] {
    return recordNoteBodies.map { url, body in
      RecordNoteEntry(url: url, body: body)
    }.sorted {
      $0.filename.compare($1.filename) == .orderedAscending
    }
  }

  func addNote(shortName: String) {
    let recordNoteURL = recordNoteService.generateRecordNoteURL(
      screenRecordEntry: screenRecordEntry, shortName: shortName
    )
    recordNoteBodies[recordNoteURL] = ""
  }

  func putNote(recordNoteURL: URL, body: String) {
    recordNoteBodies[recordNoteURL] = body
  }

  func deleteNote(recordNoteURL: URL) {
    recordNoteBodies.removeValue(forKey: recordNoteURL)
  }

  func saveAllNotes() {
    let recordNoteEntries = recordNoteBodies.map { url, body in
      RecordNoteEntry(url: url, body: body)
    }
    recordNoteService.saveRecordNotes(recordNoteEntries: recordNoteEntries)
  }
}
