import UIKit

class ScreenRecordService {
  let fileManager: FileManager
  let recoreonPathService: RecoreonPathService

  init(_ fileManager: FileManager, _ recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
  }

  func listScreenRecordURLs() -> [URL] {
    return recoreonPathService.listRecordURLs()
  }

  func listScreenRecordEntries(screenRecordURLs: [URL]) -> [ScreenRecordEntry] {
    return screenRecordURLs.map { url in
      let attrs = try? fileManager.attributesOfItem(atPath: url.path())
      return ScreenRecordEntry(
        url: url,
        size: attrs?[.size] as? UInt64 ?? 0,
        creationDate: attrs?[.creationDate] as? Date ?? Date(timeIntervalSince1970: 0)
      )
    }
  }

  func createRecordNoteService() -> RecordNoteService {
    return RecordNoteService(recoreonPathService)
  }
}
