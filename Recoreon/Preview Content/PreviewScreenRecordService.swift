import RecoreonCommon

struct PreviewScreenRecordService: ScreenRecordService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService
  private let defaultImpl: ScreenRecordService

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
    defaultImpl = DefaultScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
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

  func removeScreenRecordAndRelatedFiles(screenRecordEntry: ScreenRecordEntry) {
    defaultImpl.removeScreenRecordAndRelatedFiles(screenRecordEntry: screenRecordEntry)
  }

  func removePreviewVideo(screenRecordEntry: ScreenRecordEntry) {
    defaultImpl.removePreviewVideo(screenRecordEntry: screenRecordEntry)
  }

  func removeRecordNoteSubDir(screenRecordEntry: ScreenRecordEntry) {
    defaultImpl.removeRecordNoteSubDir(screenRecordEntry: screenRecordEntry)
  }

  func removeScreenRecord(screenRecordEntry: ScreenRecordEntry) {
    defaultImpl.removeScreenRecord(screenRecordEntry: screenRecordEntry)
  }
}
