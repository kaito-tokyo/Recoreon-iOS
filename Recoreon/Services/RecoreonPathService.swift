protocol RecoreonPathService {
  func getRecordID(screenRecordURL url: URL) -> String
  func mkdirp(url: URL)
  func generateRecordID(date: Date) -> String

  // AppGroupScreenRecord
  func generateAppGroupScreenRecordURL(recordID: String, ext: String) -> URL
  func listScreenRecordURLs() -> [URL]

  // ScreenRecord
  func getRecordNoteSubDirURL(screenRecordURL: URL) -> URL
  func listRecordNoteURLs(screenRecordURL: URL) -> [URL]
  func generateRecordNoteSubDirURL(recordID: String) -> URL
  func generateRecordNoteURL(recordID: String, shortName: String) -> URL

  // PreviewVideo
  func getPreviewVideoURL(recordID: String) -> URL

  // EncodedVideo
  func generateEncodedVideoURL(recordID: String, presetName: String) -> URL
}
