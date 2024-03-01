import SwiftUI

class RecordNoteStore: ObservableObject {
  let recordNoteService: RecordNoteService
  let screenRecordEntry: ScreenRecordEntry

  @Published var recordNoteBodies: [URL: String] = [:]

  init(recordNoteService: RecordNoteService, screenRecordEntry: ScreenRecordEntry) {
    self.recordNoteService = recordNoteService
    self.screenRecordEntry = screenRecordEntry
    let recordNoteURLs = recordNoteService.listRecordNoteURLs(
      screenRecordURL: screenRecordEntry.url)
    let recordNoteEntries = recordNoteService.listRecordNoteEntries(
      recordNoteURLs: recordNoteURLs)
    self.recordNoteBodies = Dictionary(
      uniqueKeysWithValues: recordNoteEntries.map {
        ($0.url, $0.body)
      })
  }

  func addNote(shortName: String) {
    let recordNoteURL = recordNoteService.generateRecordNoteURL(
      screenRecordURL: screenRecordEntry.url,
      shortName: shortName
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
    recordNoteService.saveRecordNotes(recordNoteEntries)
  }
}
