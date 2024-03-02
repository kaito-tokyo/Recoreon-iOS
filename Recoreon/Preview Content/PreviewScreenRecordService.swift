struct PreviewScreenRecordService: ScreenRecordService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
  }

  private let dateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  private var screenRecordEntries: [ScreenRecordEntry] = {
    let record01Url = Bundle.main.url(forResource: "Record01", withExtension: "mkv")
    let record01Attrs = try? FileManager.default.attributesOfItem(atPath: record01Url!.path)
    let record01Size = record01Attrs?[.size] as? UInt64
    let record01CreationDate = record01Attrs?[.creationDate] as? Date
    let record01Entry = ScreenRecordEntry(
      url: record01Url!,
      size: record01Size!,
      creationDate: record01CreationDate!
    )
    return [record01Entry]
  }()

  func listScreenRecordEntries() -> [ScreenRecordEntry] {
    return screenRecordEntries
  }

  func remuxPreviewVideo(screenRecordEntry: ScreenRecordEntry) async -> URL? {
    sleep(3)
    return Bundle.main.url(forResource: "Preview01", withExtension: "mp4")
  }

  func createRecordNoteService() -> RecordNoteService {
    return RecordNoteServiceMock()
  }

  func createEncodeService() -> EncodeService {
    return EncodeServiceMock()
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
