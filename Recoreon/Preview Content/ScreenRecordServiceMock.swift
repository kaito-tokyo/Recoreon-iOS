class ScreenRecordServiceMock: ScreenRecordService {
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

  init() {
    let fileManager = FileManager.default
    super.init(fileManager, RecoreonPathService(fileManager))
  }

  override func listScreenRecordURLs() -> [URL] {
    return screenRecordEntries.map { $0.url }
  }

  override func listScreenRecordEntries(screenRecordURLs: [URL]) -> [ScreenRecordEntry] {
    return screenRecordEntries
  }

  override func remuxPreviewVideo(screenRecordURL: URL) async -> URL? {
    sleep(3)
    return Bundle.main.url(forResource: "Preview01", withExtension: "mp4")
  }

  override func createRecordNoteService() -> RecordNoteService {
    return RecordNoteServiceMock()
  }
}
