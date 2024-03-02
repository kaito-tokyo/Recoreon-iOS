protocol ScreenRecordService {
  func listScreenRecordEntries() -> [ScreenRecordEntry]
  func remuxPreviewVideo(screenRecordEntry: ScreenRecordEntry) async -> URL?
  func removeScreenRecordAndRelatedFiles(screenRecordEntry: ScreenRecordEntry)
  func removePreviewVideo(screenRecordEntry: ScreenRecordEntry)
  func removeRecordNoteSubDir(screenRecordEntry: ScreenRecordEntry)
  func removeScreenRecord(screenRecordEntry: ScreenRecordEntry)
}
