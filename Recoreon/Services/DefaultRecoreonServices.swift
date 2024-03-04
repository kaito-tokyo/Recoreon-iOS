import RecoreonCommon

struct DefaultRecoreonServices: RecoreonServices {
  let encodeService: EncodeService
  let recordNoteService: RecordNoteService
  let appGroupsPreferenceService: AppGroupsPreferenceService
  let recoreonPathService: RecoreonPathService
  let screenRecordService: ScreenRecordService

  init() {
    let fileManager = FileManager.default
    let recoreonPathService = RecoreonPathService(fileManager: fileManager)

    encodeService = DefaultEncodeService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
    recordNoteService = DefaultRecordNoteService(recoreonPathService: recoreonPathService)
    appGroupsPreferenceService = AppGroupsPreferenceService()
    self.recoreonPathService = recoreonPathService
    screenRecordService = DefaultScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}
