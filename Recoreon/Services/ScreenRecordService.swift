import Foundation

protocol ScreenRecordService {
  func listScreenRecordEntries() -> [ScreenRecordEntry]
  func removeScreenRecordAndRelatedFiles(screenRecordEntry: ScreenRecordEntry)
  func removePreviewVideo(screenRecordEntry: ScreenRecordEntry)
  func removeRecordNoteSubDir(screenRecordEntry: ScreenRecordEntry)
  func removeScreenRecord(screenRecordEntry: ScreenRecordEntry)
}
