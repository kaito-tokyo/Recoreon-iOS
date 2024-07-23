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
    let recoreonPathService = RecoreonPathService(fileManager: fileManager, isUITest: true)

    appGroupsPreferenceService = AppGroupsPreferenceService()
    encodeService = PreviewEncodeService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
    recordNoteService = DefaultRecordNoteService(recoreonPathService: recoreonPathService)
    self.recoreonPathService = recoreonPathService
    screenRecordService = DefaultScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
  }

  func deployAllAssets() {
    let recoreon20240724T063654URL = recoreonPathService.generateAppGroupsFragmentedRecordURL(
      recordID: "Recoreon20240724T063654")

    let recoreon20240724T063654StreamFiles = [
      "Recoreon20240724T063654-app-000000",
      "Recoreon20240724T063654-app-000001",
      "Recoreon20240724T063654-app-000002",
      "Recoreon20240724T063654-app-init",
      "Recoreon20240724T063654-mic-000000",
      "Recoreon20240724T063654-mic-000001",
      "Recoreon20240724T063654-mic-000002",
      "Recoreon20240724T063654-mic-init",
      "Recoreon20240724T063654-video-000000",
      "Recoreon20240724T063654-video-000001",
      "Recoreon20240724T063654-video-000002",
      "Recoreon20240724T063654-video-init",
    ]
    for streamFile in recoreon20240724T063654StreamFiles {
      copyIfNotExists(
        at: Bundle.main.url(
          forResource: streamFile,
          withExtension: "m4s"
        )!,
        to: recoreon20240724T063654URL.appending(
          path: "\(streamFile).m4s", directoryHint: .notDirectory)
      )
    }

    let recoreon20240724T063654IndexFiles = [
      "Recoreon20240724T063654-app",
      "Recoreon20240724T063654-mic",
      "Recoreon20240724T063654-video",
      "Recoreon20240724T063654",
    ]

    for indexFile in recoreon20240724T063654IndexFiles {
      copyIfNotExists(
        at: Bundle.main.url(
          forResource: indexFile,
          withExtension: "m3u8"
        )!,
        to: recoreon20240724T063654URL.appending(
          path: "\(indexFile).m3u8", directoryHint: .notDirectory)
      )
    }

    let recoreon20240724T063710URL = recoreonPathService.generateAppGroupsFragmentedRecordURL(
      recordID: "Recoreon20240724T063710")

    let recoreon20240724T063710StreamFiles = [
      "Recoreon20240724T063710-app-000000",
      "Recoreon20240724T063710-app-000001",
      "Recoreon20240724T063710-app-init",
      "Recoreon20240724T063710-mic-000000",
      "Recoreon20240724T063710-mic-000001",
      "Recoreon20240724T063710-mic-init",
      "Recoreon20240724T063710-video-000000",
      "Recoreon20240724T063710-video-000001",
      "Recoreon20240724T063710-video-init",
    ]
    for streamFile in recoreon20240724T063710StreamFiles {
      copyIfNotExists(
        at: Bundle.main.url(
          forResource: streamFile,
          withExtension: "m4s"
        )!,
        to: recoreon20240724T063710URL.appending(
          path: "\(streamFile).m4s", directoryHint: .notDirectory)
      )
    }

    let recoreon20240724T063710IndexFiles = [
      "Recoreon20240724T063710-app",
      "Recoreon20240724T063710-mic",
      "Recoreon20240724T063710-video",
      "Recoreon20240724T063710",
    ]

    for indexFile in recoreon20240724T063710IndexFiles {
      copyIfNotExists(
        at: Bundle.main.url(
          forResource: indexFile,
          withExtension: "m3u8"
        )!,
        to: recoreon20240724T063710URL.appending(
          path: "\(indexFile).m3u8", directoryHint: .notDirectory)
      )
    }

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Recoreon20240724T063654-1", withExtension: "txt")!,
      to: recoreonPathService.generateRecordNoteURL(
        recordID: "Recoreon20240724T063654", shortName: "1")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Recoreon20240724T063654-2", withExtension: "txt")!,
      to: recoreonPathService.generateRecordNoteURL(
        recordID: "Recoreon20240724T063654", shortName: "2")
    )

    copyIfNotExists(
      at: Bundle.main.url(forResource: "Recoreon20240724T063654-summary", withExtension: "txt")!,
      to: recoreonPathService.generateRecordSummaryURL(recordID: "Recoreon20240724T063654")
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
