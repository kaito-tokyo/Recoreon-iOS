class RecoreonPathService {
  static let appGroupIdentifier = "group.com.github.umireon.Recoreon"

  let fileManager: FileManager

  let appGroupDir: URL
  let appGroupDocumentsDir: URL
  let appGroupRecordsDir: URL
  let libraryDir: URL
  let previewsDir: URL
  let thumbnailsDir: URL
  let encodedVideosDir: URL
  let documentsDir: URL
  let recordsDir: URL
  let recordNotesDir: URL

  init(_ fileManager: FileManager) {
    self.fileManager = fileManager
    appGroupDir = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)!
    appGroupDocumentsDir = appGroupDir.appending(
      component: "Documents", directoryHint: .isDirectory)
    appGroupRecordsDir = appGroupDocumentsDir.appending(
      path: "Records", directoryHint: .isDirectory)
    libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
    previewsDir = libraryDir.appending(path: "Previews", directoryHint: .isDirectory)
    thumbnailsDir = libraryDir.appending(path: "Thumbnails", directoryHint: .isDirectory)
    encodedVideosDir = libraryDir.appending(path: "EncodedVideos", directoryHint: .isDirectory)
    documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    recordsDir = documentsDir.appending(path: "Records", directoryHint: .isDirectory)
    recordNotesDir = documentsDir.appending(path: "RecordNotes", directoryHint: .isDirectory)
  }

  func getRecordID(screenRecordURL url: URL) -> String {
    return url.deletingPathExtension().lastPathComponent
  }

  func generateRecordNoteSubDirURL(recordID: String) -> URL {
    let subDirURL = recordNotesDir.appending(component: recordID, directoryHint: .isDirectory)
    mkdirp(url: subDirURL)
    return subDirURL
  }

  func generateRecordNoteURL(recordID: String, shortName: String, ext: String = "txt") -> URL {
    let subDirURL = generateRecordNoteSubDirURL(recordID: recordID)
    return subDirURL.appending(
      component: "\(recordID)-\(shortName).\(ext)", directoryHint: .notDirectory)
  }

  func ensureAppGroupDirectoriesExists() {
    try? fileManager.createDirectory(at: appGroupRecordsDir, withIntermediateDirectories: true)
  }

  private func mkdirp(url: URL) {
    try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
  }

  func ensureSandboxDirectoriesExists() {
    try? fileManager.createDirectory(at: recordsDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: encodedVideosDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: previewsDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: recordNotesDir, withIntermediateDirectories: true)
  }

  func listRecordURLs() -> [URL] {
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: appGroupRecordsDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return urls.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }

  func getThumbnailURL(_ recordedVideoURL: URL, ext: String = "jpg") -> URL {
    let filename = recordedVideoURL.deletingPathExtension().appendingPathExtension(ext)
      .lastPathComponent
    return thumbnailsDir.appending(path: filename, directoryHint: .notDirectory)
  }

  func getResampledAudioURL(_ recordedVideoURL: URL, suffix: String, ext: String = "m4a") -> URL {
    let filename = recordedVideoURL.deletingPathExtension().lastPathComponent + "\(suffix).\(ext)"
    return encodedVideosDir.appending(path: filename, directoryHint: .notDirectory)
  }

  func getEncodedVideoURL(_ recordedVideoURL: URL, suffix: String, ext: String = "mp4") -> URL {
    let filename = recordedVideoURL.deletingPathExtension().lastPathComponent + "\(suffix).\(ext)"
    return encodedVideosDir.appending(path: filename, directoryHint: .notDirectory)
  }

  func getSharedScreenRecordURL(_ recordedVideoURL: URL) -> URL {
    let filename = recordedVideoURL.lastPathComponent
    return recordsDir.appending(path: filename, directoryHint: .notDirectory)
  }

  func getPreviewVideoURL(screenRecordURL: URL) -> URL {
    let filename = screenRecordURL.deletingPathExtension().appendingPathExtension("mp4")
      .lastPathComponent
    return previewsDir.appending(path: filename, directoryHint: .notDirectory)
  }

  func getRecordNoteSubDirURL(screenRecordURL: URL) -> URL {
    let recordId = screenRecordURL.deletingPathExtension().lastPathComponent
    let url = recordNotesDir.appending(component: recordId, directoryHint: .isDirectory)
    try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  func listRecordNoteURLs(screenRecordURL: URL) -> [URL] {
    let recordNotesSubDir = getRecordNoteSubDirURL(screenRecordURL: screenRecordURL)
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: recordNotesSubDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return urls.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }
}
