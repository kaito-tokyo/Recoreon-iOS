import RecoreonCommon

protocol RecoreonServices {
  var appGroupsPreferenceService: AppGroupsPreferenceService { get }
  var recordNoteService: RecordNoteService { get }
  var recoreonPathService: RecoreonPathService { get }
  var screenRecordService: ScreenRecordService { get }
}
