import SwiftUI

class RecordNoteStore: ObservableObject {
  let screenRecordService: ScreenRecordService
  let screenRecordEntry: ScreenRecordEntry

  @Published var recordNoteBodies: [URL: String] = [:]

  init(_ screenRecordService: ScreenRecordService, _ screenRecordEntry: ScreenRecordEntry) {
    self.screenRecordService = screenRecordService
    self.screenRecordEntry = screenRecordEntry
    let recordNoteEntries = screenRecordService.listRecordNoteEntries(screenRecordEntry)
    self.recordNoteBodies = Dictionary(uniqueKeysWithValues: recordNoteEntries.map {
      ($0.url, $0.body)
    })
  }

  func addNote(shortName: String) {
    let recordNoteURL = screenRecordService.getRecordNoteURL(screenRecordEntry, shortName: shortName)
    recordNoteBodies[recordNoteURL] = ""
  }

  func putNote(recordNoteURL: URL, body: String) {
    recordNoteBodies[recordNoteURL] = body
  }

  func deleteNote(recordNoteURL: URL) {
    recordNoteBodies.removeValue(forKey: recordNoteURL)
  }

  func saveAllNotes() {
    
  }
}