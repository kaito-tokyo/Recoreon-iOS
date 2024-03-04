import RecoreonCommon

protocol RecoreonServices {
  var encodeService: EncodeService { get }
  var recordNoteService: RecordNoteService { get }
  var appGroupsPreferenceService: AppGroupsPreferenceService { get }
  var recoreonPathService: RecoreonPathService { get }
  var screenRecordService: ScreenRecordService { get }
}
