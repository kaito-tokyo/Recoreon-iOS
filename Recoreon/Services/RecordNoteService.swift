class RecordNoteService {
  let recoreonPathService: RecoreonPathService

  init(_ recoreonPathService: RecoreonPathService) {
    self.recoreonPathService = recoreonPathService
  }

  func listRecordNoteURLs(screenRecordURL url: URL) -> [URL] {
    recoreonPathService.ensureSandboxDirectoriesExists()
    return recoreonPathService.listRecordNoteURLs(screenRecordURL: url)
  }

  func listRecordNoteEntries(recordNoteURLs: [URL]) -> [RecordNoteEntry] {
    return recordNoteURLs.map { url in
      let body = try? String(contentsOf: url)
      return RecordNoteEntry(url: url, body: body ?? "")
    }
  }

  func saveRecordNotes(_ recordNoteEntries: [RecordNoteEntry]) {
    for recordNoteEntry in recordNoteEntries {
      let body = recordNoteEntry.body
      let url = recordNoteEntry.url
      try? body.write(to: url, atomically: true, encoding: .utf8)
    }
  }
}
