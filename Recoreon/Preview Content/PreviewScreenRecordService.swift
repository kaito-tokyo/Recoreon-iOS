import RecoreonCommon

// swiftlint:disable force_try force_cast
class PreviewScreenRecordService: ScreenRecordService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService
  private let defaultImpl: ScreenRecordService

  private let dateFormatter: ISO8601DateFormatter

  private var screenRecordEntries: [ScreenRecordEntry] = []

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
    self.defaultImpl = DefaultScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current
    self.dateFormatter = formatter
  }

  private func updateScreenRecordEntries() {
    let record01URL = Bundle.main.url(forResource: "Record01", withExtension: "mkv")!
    let record01Attrs = try! fileManager.attributesOfItem(
      atPath: record01URL.path(percentEncoded: false))
    let record01Size = record01Attrs[.size] as! UInt64
    let record01CreationDate = record01Attrs[.creationDate] as! Date
    let record01SummaryURL = recoreonPathService.generateRecordSummaryURL(recordID: "Record01")
    let record01SummaryBody = try? String(contentsOf: record01SummaryURL)
    let record01Entry = ScreenRecordEntry(
      url: record01URL,
      size: record01Size,
      creationDate: record01CreationDate,
      summaryBody: record01SummaryBody ?? ""
    )

    let record02URL = Bundle.main.url(forResource: "Record02", withExtension: "mkv")!
    let record02Attrs = try! fileManager.attributesOfItem(
      atPath: record02URL.path(percentEncoded: false))
    let record02Size = record02Attrs[.size] as! UInt64
    let record02CreationDate = record02Attrs[.creationDate] as! Date
    let record02SummaryURL = recoreonPathService.generateRecordSummaryURL(recordID: "Record02")
    let record02SummaryBody = try? String(contentsOf: record02SummaryURL)
    let record02Entry = ScreenRecordEntry(
      url: record02URL,
      size: record02Size,
      creationDate: record02CreationDate,
      summaryBody: record02SummaryBody ?? ""
    )

    self.screenRecordEntries = [record01Entry, record02Entry]
  }

  func listScreenRecordEntries() -> [ScreenRecordEntry] {
    updateScreenRecordEntries()
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
// swiftlint:enable force_try force_cast
