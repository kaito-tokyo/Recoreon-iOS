struct DefaultRecoreonPathService: RecoreonPathService {
  private static let appGroupIdentifier = "group.com.github.umireon.Recoreon"

  private let fileManager: FileManager

  private let appGroupDir: URL
  private let appGroupDocumentsDir: URL
  private let appGroupRecordsDir: URL
  private let libraryDir: URL
  private let previewVideosDir: URL
  private let encodedVideosDir: URL
  private let documentsDir: URL
  private let recordsDir: URL
  private let recordNotesDir: URL

  init(fileManager: FileManager) {
    self.fileManager = fileManager
    appGroupDir = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)!
    appGroupDocumentsDir = appGroupDir.appending(
      component: "Documents", directoryHint: .isDirectory)
    appGroupRecordsDir = appGroupDocumentsDir.appending(
      path: "Records", directoryHint: .isDirectory)
    libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
    previewVideosDir = libraryDir.appending(path: "PreviewVideos", directoryHint: .isDirectory)
    encodedVideosDir = libraryDir.appending(path: "EncodedVideos", directoryHint: .isDirectory)
    documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    recordsDir = documentsDir.appending(path: "Records", directoryHint: .isDirectory)
    recordNotesDir = documentsDir.appending(path: "RecordNotes", directoryHint: .isDirectory)
  }

  func getRecordID(screenRecordURL url: URL) -> String {
    return url.deletingPathExtension().lastPathComponent
  }

  func mkdirp(url: URL) {
    try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
  }

  func generateRecordID(date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current

    let recordDatetime = formatter.string(from: date)
    let recordID = "Recoreon\(recordDatetime)"
    return recordID
  }

  // ScreenRecord

  func generateAppGroupScreenRecordURL(recordID: String, ext: String) -> URL {
    mkdirp(url: appGroupRecordsDir)
    let appGroupScreenRecordURL = appGroupRecordsDir.appending(
      path: "\(recordID).\(ext)", directoryHint: .notDirectory)
    return appGroupScreenRecordURL
  }

  func listScreenRecordURLs() -> [URL] {
    guard
      let screenRecordURLs = try? fileManager.contentsOfDirectory(
        at: appGroupRecordsDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return screenRecordURLs.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }

  // RecordNote

  func getRecordNoteSubDirURL(screenRecordURL: URL) -> URL {
    let recordId = screenRecordURL.deletingPathExtension().lastPathComponent
    let recordNoteSubDirURL = recordNotesDir.appending(path: recordId, directoryHint: .isDirectory)
    mkdirp(url: recordNoteSubDirURL)
    return recordNoteSubDirURL
  }

  func listRecordNoteURLs(screenRecordURL: URL) -> [URL] {
    let recordNotesSubDir = getRecordNoteSubDirURL(screenRecordURL: screenRecordURL)
    guard
      let recordNoteURLs = try? fileManager.contentsOfDirectory(
        at: recordNotesSubDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return recordNoteURLs.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }

  func generateRecordNoteSubDirURL(recordID: String) -> URL {
    let subDirURL = recordNotesDir.appending(component: recordID, directoryHint: .isDirectory)
    mkdirp(url: subDirURL)
    return subDirURL
  }

  func generateRecordNoteURL(recordID: String, shortName: String) -> URL {
    let subDirURL = generateRecordNoteSubDirURL(recordID: recordID)
    let ext = "txt"
    return subDirURL.appending(
      path: "\(recordID)-\(shortName).\(ext)", directoryHint: .notDirectory)
  }

  // PreviewVideo

  func getPreviewVideoURL(recordID: String) -> URL {
    let ext = "mp4"
    mkdirp(url: previewVideosDir)
    let previewVideoURL = previewVideosDir.appending(
      path: "$\(recordID).\(ext)", directoryHint: .notDirectory)
    return previewVideoURL
  }

  // EncodedVideo

  func generateEncodedVideoURL(recordID: String, presetName: String) -> URL {
    let ext = "mp4"
    mkdirp(url: encodedVideosDir)
    return encodedVideosDir.appending(
      path: "\(recordID)-\(presetName).\(ext)", directoryHint: .notDirectory)
  }
}
