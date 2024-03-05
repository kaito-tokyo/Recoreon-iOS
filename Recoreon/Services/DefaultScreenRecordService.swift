import RecoreonCommon

struct DefaultScreenRecordService: ScreenRecordService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
  }

  func listScreenRecordEntries() -> [ScreenRecordEntry] {
    let screenRecordURLs = recoreonPathService.listScreenRecordURLs()
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

  func remuxPreviewVideo(screenRecordEntry: ScreenRecordEntry) async -> URL? {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    let previewVideoURL = recoreonPathService.getPreviewVideoURL(recordID: recordID)

    if fileManager.fileExists(atPath: previewVideoURL.path(percentEncoded: false)) {
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
}
