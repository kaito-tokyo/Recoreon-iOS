import Foundation
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
    screenRecordService = DefaultScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
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
      to: recoreonPathService.generateRecordNoteURL(recordID: "Record01", shortName: "1")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record01-2", withExtension: "txt")!,
      to: recoreonPathService.generateRecordNoteURL(recordID: "Record01", shortName: "2")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Record01-summary", withExtension: "txt")!,
      to: recoreonPathService.generateRecordSummaryURL(recordID: "Record01")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Preview01", withExtension: "mp4")!,
      to: recoreonPathService.generatePreviewVideoURL(recordID: "Record01")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Preview02", withExtension: "mp4")!,
      to: recoreonPathService.generatePreviewVideoURL(recordID: "Record02")
    )
  }

  // swiftlint:disable force_try identifier_name
  func copyIfNotExists(at: URL, to: URL) {
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: to.path(percentEncoded: false)) {
      try! fileManager.copyItem(at: at, to: to)
    }
  }
  // swiftlint:enable force_try identifier_name
}
