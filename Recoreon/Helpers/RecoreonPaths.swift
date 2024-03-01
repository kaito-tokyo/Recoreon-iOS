private let fileManager = FileManager.default

class RecoreonPaths {
  static let appGroupIdentifier = "group.com.github.umireon.Recoreon"

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

  init() {
    appGroupDir = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: RecoreonPaths.appGroupIdentifier)!
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

  func ensureAppGroupDirectoriesExists() {
    try? fileManager.createDirectory(at: appGroupRecordsDir, withIntermediateDirectories: true)
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

  func getPreviewVideoURL(_ recordedVideoURL: URL, ext: String = "mp4") -> URL {
    let filename = recordedVideoURL.deletingPathExtension().appendingPathExtension(ext)
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