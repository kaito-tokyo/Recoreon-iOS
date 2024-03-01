class RecordNoteServiceMock: RecordNoteService {
  private var recordNoteEntries = {
    let record01Note1Url = Bundle.main.url(forResource: "Record01-1", withExtension: "txt")
    let record01Note1Body = try? String(contentsOf: record01Note1Url!)
    let record01Note1Entry = RecordNoteEntry(url: record01Note1Url!, body: record01Note1Body!)

    let record01Note2Url = Bundle.main.url(forResource: "Record01-2", withExtension: "txt")
    let record01Note2Body = try? String(contentsOf: record01Note2Url!)
    let record01Note2Entry = RecordNoteEntry(url: record01Note2Url!, body: record01Note2Body!)

    return [record01Note1Entry, record01Note2Entry]
  }()

  init() {
    super.init(RecoreonPathService(FileManager.default))
  }

  override func listRecordNoteURLs(screenRecordURL url: URL) -> [URL] {
    return recordNoteEntries.map { $0.url }
  }

  override func listRecordNoteEntries(recordNoteURLs: [URL]) -> [RecordNoteEntry] {
    return recordNoteEntries
  }
}
