import Foundation
import RecoreonCommon

struct DefaultScreenRecordService: ScreenRecordService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
  }

  func listScreenRecordEntries() -> [ScreenRecordEntry] {
    let screenRecordURLs = recoreonPathService.listFragmentedRecordURLs()
    return screenRecordURLs.map { screenRecordURL in
      let attrs = try? fileManager.attributesOfItem(atPath: screenRecordURL.path())
      let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordURL)
      let recordSummaryURL = recoreonPathService.generateRecordSummaryURL(recordID: recordID)
      let recordSummaryBody = try? String(contentsOf: recordSummaryURL, encoding: .utf8)
      return ScreenRecordEntry(
        url: screenRecordURL,
        size: attrs?[.size] as? UInt64 ?? 0,
        creationDate: attrs?[.creationDate] as? Date ?? Date(timeIntervalSince1970: 0),
        summaryBody: recordSummaryBody ?? ""
      )
    }
  }

  func removeScreenRecordAndRelatedFiles(screenRecordEntry: ScreenRecordEntry) {
    removePreviewVideo(screenRecordEntry: screenRecordEntry)
    removeRecordNoteSubDir(screenRecordEntry: screenRecordEntry)
    removeScreenRecord(screenRecordEntry: screenRecordEntry)
  }

  func removePreviewVideo(screenRecordEntry: ScreenRecordEntry) {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    let previewVideoURL = recoreonPathService.generatePreviewVideoURL(recordID: recordID)
    try? fileManager.removeItem(at: previewVideoURL)
  }

  func removeRecordNoteSubDir(screenRecordEntry: ScreenRecordEntry) {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    let recordNoteSubDir = recoreonPathService.generateRecordNoteSubDirURL(recordID: recordID)
    try? fileManager.removeItem(at: recordNoteSubDir)
  }

  func removeScreenRecord(screenRecordEntry: ScreenRecordEntry) {
    try? fileManager.removeItem(at: screenRecordEntry.url)
  }
}
