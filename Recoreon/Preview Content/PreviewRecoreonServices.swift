import RecoreonCommon

struct PreviewRecoreonServices: RecoreonServices {
  let encodeService: EncodeService
  let recordNoteService: RecordNoteService
  let appGroupsPreferenceService: AppGroupsPreferenceService
  let recoreonPathService: RecoreonPathService
  let screenRecordService: ScreenRecordService

  init() {
    let fileManager = FileManager.default
    let recoreonPathService = RecoreonPathService(fileManager: fileManager)

    encodeService = PreviewEncodeService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
    recordNoteService = PreviewRecordNoteService(recoreonPathService: recoreonPathService)
    appGroupsPreferenceService = AppGroupsPreferenceService()
    self.recoreonPathService = recoreonPathService
    screenRecordService = PreviewScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}
