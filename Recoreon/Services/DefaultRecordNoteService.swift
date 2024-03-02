struct DefaultRecordNoteService: RecordNoteService {
  private let recoreonPathService: RecoreonPathService

  init(recoreonPathService: RecoreonPathService) {
    self.recoreonPathService = recoreonPathService
  }

  func listRecordNoteEntries(screenRecordEntry: ScreenRecordEntry) -> [RecordNoteEntry] {
    let recordNoteURLs = recoreonPathService.listRecordNoteURLs(
      screenRecordURL: screenRecordEntry.url)
    return recordNoteURLs.map { url in
      let body = try? String(contentsOf: url)
      return RecordNoteEntry(url: url, body: body ?? "")
    }
  }

  func generateRecordNoteURL(screenRecordEntry: ScreenRecordEntry, shortName: String) -> URL {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    return recoreonPathService.generateRecordNoteURL(recordID: recordID, shortName: shortName)
  }

  func saveRecordNotes(recordNoteEntries: [RecordNoteEntry]) {
    for recordNoteEntry in recordNoteEntries {
      let body = recordNoteEntry.body
      let url = recordNoteEntry.url
      try? body.write(to: url, atomically: true, encoding: .utf8)
    }
  }
}
