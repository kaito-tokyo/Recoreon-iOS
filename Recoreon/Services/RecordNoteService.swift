protocol RecordNoteService {
  func listRecordNoteEntries(screenRecordEntry: ScreenRecordEntry) -> [RecordNoteEntry]
  func generateRecordNoteURL(screenRecordEntry: ScreenRecordEntry, shortName: String) -> URL
  func saveRecordNotes(recordNoteEntries: [RecordNoteEntry])
}
