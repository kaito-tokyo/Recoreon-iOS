protocol RecordNoteService {
  func listRecordNoteEntries(screenRecordEntry: ScreenRecordEntry) -> [RecordNoteEntry]
  func generateRecordNoteURL(screenRecordEntry: ScreenRecordEntry, shortName: String) -> URL
  func extractRecordNoteShortName(recordNoteEntry: RecordNoteEntry) -> String
  func saveRecordNotes(recordNoteEntries: [RecordNoteEntry])
}
