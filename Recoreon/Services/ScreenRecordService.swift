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

  func remuxPreviewVideo(screenRecordURL: URL) async -> URL? {
    let previewVideoURL = recoreonPathService.getPreviewVideoURL(screenRecordURL: screenRecordURL)

    if fileManager.fileExists(atPath: previewVideoURL.path()) {
      return previewVideoURL
    }

    let arguments = [
      "-i",
      screenRecordURL.path(),
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

  func removeScreenRecordAndRelatedFiles(screenRecordURL: URL) {
    removePreviewVideo(screenRecordURL: screenRecordURL)
    removeRecordNoteSubDir(screenRecordURL: screenRecordURL)
    removeScreenRecord(screenRecordURL: screenRecordURL)
  }

  func removePreviewVideo(screenRecordURL: URL) {
    let previewVideoURL = recoreonPathService.getPreviewVideoURL(screenRecordURL: screenRecordURL)
    try? fileManager.removeItem(at: previewVideoURL)
  }

  func removeRecordNoteSubDir(screenRecordURL: URL) {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordURL)
    let recordNoteSubDir = recoreonPathService.generateRecordNoteSubDirURL(recordID: recordID)
    try? fileManager.removeItem(at: recordNoteSubDir)
  }

  func removeScreenRecord(screenRecordURL: URL) {
    try? fileManager.removeItem(at: screenRecordURL)
  }

  func createRecordNoteService() -> RecordNoteService {
    return RecordNoteService(recoreonPathService)
  }

  func createEncodeService() -> EncodeService {
    return EncodeService(fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}
