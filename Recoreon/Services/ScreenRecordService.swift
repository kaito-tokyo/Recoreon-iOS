import UIKit

class ScreenRecordService {
  let fileManager: FileManager
  let recoreonPathService: RecoreonPathService

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
  }

  func listScreenRecordEntries() -> [ScreenRecordEntry] {
    let screenRecordURLs = recoreonPathService.listScreenRecordURLs()
    return screenRecordURLs.map { url in
      let attrs = try? fileManager.attributesOfItem(atPath: url.path())
      return ScreenRecordEntry(
        url: url,
        size: attrs?[.size] as? UInt64 ?? 0,
        creationDate: attrs?[.creationDate] as? Date ?? Date(timeIntervalSince1970: 0)
      )
    }
  }

  func remuxPreviewVideo(screenRecordEntry: ScreenRecordEntry) async -> URL? {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    let previewVideoURL = recoreonPathService.getPreviewVideoURL(recordID: recordID)

    if fileManager.fileExists(atPath: previewVideoURL.path()) {
      return previewVideoURL
    }

    let arguments = [
      "-i",
      screenRecordEntry.url.path(),
      "-c:v",
      "copy",
      "-c:a",
      "copy",
      previewVideoURL.path(),
    ]

    return await withCheckedContinuation { continuation in
      FFmpegKit.execute(
        withArgumentsAsync: arguments,
        withCompleteCallback: { session in
          let ret = session?.getReturnCode()
          if ReturnCode.isSuccess(ret) {
            continuation.resume(returning: previewVideoURL)
          } else {
            continuation.resume(returning: nil)
          }
        }
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
    let previewVideoURL = recoreonPathService.getPreviewVideoURL(recordID: recordID)
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

  func createRecordNoteService() -> RecordNoteService {
    return RecordNoteService(recoreonPathService)
  }

  func createEncodeService() -> EncodeService {
    return EncodeService(fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}
