import RecoreonCommon

struct PreviewRecordNoteService: RecordNoteService {
  private let recoreonPathService: RecoreonPathService
  private let defaultImpl: RecordNoteService

  private var recordNoteEntries = {
    let record01Note1Url = Bundle.main.url(forResource: "Record01-1", withExtension: "txt")
    let record01Note1Body = try? String(contentsOf: record01Note1Url!)
    let record01Note1Entry = RecordNoteEntry(url: record01Note1Url!, body: record01Note1Body!)

    let record01Note2Url = Bundle.main.url(forResource: "Record01-2", withExtension: "txt")
    let record01Note2Body = try? String(contentsOf: record01Note2Url!)
    let record01Note2Entry = RecordNoteEntry(url: record01Note2Url!, body: record01Note2Body!)

    let record01SummaryUrl = Bundle.main.url(forResource: "Record01-summary", withExtension: "txt")
    let record01SummaryBody = try? String(contentsOf: record01SummaryUrl!)
    let record01SummaryEntry = RecordNoteEntry(url: record01SummaryUrl!, body: record01SummaryBody!)

    return [record01Note1Entry, record01Note2Entry, record01SummaryEntry]
  }()

  init(recoreonPathService: RecoreonPathService) {
    self.recoreonPathService = recoreonPathService
    self.defaultImpl = DefaultRecordNoteService(recoreonPathService: recoreonPathService)
  }

  func listRecordNoteEntries(screenRecordEntry: ScreenRecordEntry) -> [RecordNoteEntry] {
    return recordNoteEntries
  }

  func filterOutReservedRecordNoteEntries(
    recordNoteEntries: [RecordNoteEntry]
  ) -> [RecordNoteEntry] {
    return defaultImpl.filterOutReservedRecordNoteEntries(recordNoteEntries: recordNoteEntries)
  }

  func readRecordSummaryEntry(screenRecordEntry: ScreenRecordEntry) -> RecordNoteEntry {
    return recordNoteEntries[2]
  }

  func generateRecordNoteURL(screenRecordEntry: ScreenRecordEntry, shortName: String) -> URL {
    return defaultImpl.generateRecordNoteURL(
      screenRecordEntry: screenRecordEntry, shortName: shortName)
  }

  func generateRecordSummaryURL(screenRecordEntry: ScreenRecordEntry) -> URL {
    return defaultImpl.generateRecordSummaryURL(screenRecordEntry: screenRecordEntry)
  }

  func extractRecordNoteShortName(recordNoteEntry: RecordNoteEntry) -> String {
    return defaultImpl.extractRecordNoteShortName(recordNoteEntry: recordNoteEntry)
  }

  func saveRecordNotes(recordNoteEntries: [RecordNoteEntry]) {
    defaultImpl.saveRecordNotes(recordNoteEntries: recordNoteEntries)
  }
}
