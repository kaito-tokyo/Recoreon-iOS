import RecoreonCommon

struct PreviewRecoreonServices: RecoreonServices {
  let appGroupsPreferenceService: AppGroupsPreferenceService
  let encodeService: EncodeService
  let recordNoteService: RecordNoteService
  let recoreonPathService: RecoreonPathService
  let screenRecordService: ScreenRecordService

  init() {
    let fileManager = FileManager.default
    let recoreonPathService = RecoreonPathService(fileManager: fileManager)

    appGroupsPreferenceService = AppGroupsPreferenceService()
    encodeService = PreviewEncodeService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
    recordNoteService = DefaultRecordNoteService(recoreonPathService: recoreonPathService)
    self.recoreonPathService = recoreonPathService
    screenRecordService = PreviewScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)

    // swiftlint:disable force_try
    let record01Note1BundleURL = Bundle.main.url(forResource: "Record01-1", withExtension: "txt")
    let record01Note1URL = recoreonPathService.generateRecordNoteURL(
      recordID: "Record01", shortName: "1")
    if !fileManager.fileExists(atPath: record01Note1URL.path(percentEncoded: false)) {
      try! fileManager.copyItem(at: record01Note1BundleURL!, to: record01Note1URL)
    }

    let record01Note2BundleURL = Bundle.main.url(forResource: "Record01-2", withExtension: "txt")
    let record01Note2URL = recoreonPathService.generateRecordNoteURL(
      recordID: "Record01", shortName: "2")
    if !fileManager.fileExists(atPath: record01Note2URL.path(percentEncoded: false)) {
      try! fileManager.copyItem(at: record01Note2BundleURL!, to: record01Note2URL)
    }

    let record01SummaryBundleURL = Bundle.main.url(
      forResource: "Record01-summary", withExtension: "txt")
    let record01SummaryURL = recoreonPathService.generateRecordSummaryURL(recordID: "Record01")
    if !fileManager.fileExists(atPath: record01SummaryURL.path(percentEncoded: false)) {
      try! fileManager.copyItem(at: record01SummaryBundleURL!, to: record01SummaryURL)
    }
    // swiftlint:enable force_try
  }


  func deployAllAssets() {
    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record01", withExtension: "mkv")!,
      to: recoreonPathService.generateAppGroupsScreenRecordURL(recordID: "Record01", ext: "mkv")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record02", withExtension: "mkv")!,
      to: recoreonPathService.generateAppGroupsScreenRecordURL(recordID: "Record02", ext: "mkv")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record01-1", withExtension: "txt")!,
      to: recoreonPathService.generateRecordNoteURL(recordID: "Record01-1", shortName: "txt")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record01-2", withExtension: "txt")!,
      to: recoreonPathService.generateRecordNoteURL(recordID: "Record01-2", shortName: "txt")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record01-summary", withExtension: "txt")!,
      to: recoreonPathService.generateRecordNoteURL(recordID: "Record01-summary", shortName: "txt")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Preview01", withExtension: "mp4")!,
      to: recoreonPathService.getPreviewVideoURL(recordID: "Record01")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Preview02", withExtension: "mp4")!,
      to: recoreonPathService.getPreviewVideoURL(recordID: "Record02")
    )
  }

  func copyIfNotExists(at: URL, to: URL) {
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: at.path(percentEncoded: false)) {
      try! fileManager.copyItem(at: at, to: to)
    }
  }
}
