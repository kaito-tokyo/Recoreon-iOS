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

  func createRecordNoteService() -> RecordNoteService {
    return RecordNoteService(recoreonPathService)
  }
}
