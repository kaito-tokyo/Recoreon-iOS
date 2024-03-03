protocol RecordNoteService {
  func listRecordNoteEntries(screenRecordEntry: ScreenRecordEntry) -> [RecordNoteEntry]
  func filterOutReservedRecordNoteEntries(recordNoteEntries: [RecordNoteEntry]) -> [RecordNoteEntry]
  func generateRecordNoteURL(screenRecordEntry: ScreenRecordEntry, shortName: String) -> URL
  func generateRecordSummaryURL(screenRecordEntry: ScreenRecordEntry) -> URL
  func readRecordSummaryEntry(screenRecordEntry: ScreenRecordEntry) -> RecordNoteEntry
  func extractRecordNoteShortName(recordNoteEntry: RecordNoteEntry) -> String
  func saveRecordNotes(recordNoteEntries: [RecordNoteEntry])
}
