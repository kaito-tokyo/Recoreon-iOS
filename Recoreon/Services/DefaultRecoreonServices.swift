import Foundation
import RecoreonCommon

struct DefaultRecoreonServices: RecoreonServices {
  let appGroupsPreferenceService: AppGroupsPreferenceService
  let recordNoteService: RecordNoteService
  let recoreonPathService: RecoreonPathService
  let screenRecordService: ScreenRecordService

  init() {
    let fileManager = FileManager.default
    let recoreonPathService = RecoreonPathService(fileManager: fileManager)

    appGroupsPreferenceService = AppGroupsPreferenceService()
    recordNoteService = DefaultRecordNoteService(recoreonPathService: recoreonPathService)
    self.recoreonPathService = recoreonPathService
    screenRecordService = DefaultScreenRecordService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}
