import RecoreonCommon

protocol RecoreonServices {
  var appGroupsPreferenceService: AppGroupsPreferenceService { get }
  var encodeService: EncodeService { get }
  var recordNoteService: RecordNoteService { get }
  var recoreonPathService: RecoreonPathService { get }
  var screenRecordService: ScreenRecordService { get }
}
