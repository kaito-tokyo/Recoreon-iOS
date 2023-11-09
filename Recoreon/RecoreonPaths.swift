private let fileManager = FileManager.default

class RecoreonPaths {
  static let appGroupIdentifier = "group.com.github.umireon.Recoreon"

  let appGroupDir: URL
  let documentsDir: URL
  let recordsDir: URL
  let libraryDir: URL
  let thumbnailsDir: URL
  let resampledAudiosDir: URL
  let encodedVideosDir: URL
  let sharedDocumentsDir: URL
  let sharedRecordsDir: URL

  init() {
    appGroupDir = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: RecoreonPaths.appGroupIdentifier)!
    documentsDir = appGroupDir.appending(component: "Documents", directoryHint: .isDirectory)
    recordsDir = documentsDir.appending(path: "Records", directoryHint: .isDirectory)
    libraryDir = appGroupDir.appending(path: "Library", directoryHint: .isDirectory)
    thumbnailsDir = libraryDir.appending(path: "Thumbnails", directoryHint: .isDirectory)
    resampledAudiosDir = libraryDir.appending(path: "ResampledAudios", directoryHint: .isDirectory)
    encodedVideosDir = libraryDir.appending(path: "EncodedVideos", directoryHint: .isDirectory)
    sharedDocumentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    sharedRecordsDir = sharedDocumentsDir.appending(path: "Records", directoryHint: .isDirectory)
  }

  func ensureAppGroupDirectoriesExists() {
    try? fileManager.createDirectory(at: recordsDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: resampledAudiosDir, withIntermediateDirectories: true)
    try? fileManager.createDirectory(at: encodedVideosDir, withIntermediateDirectories: true)
  }

  func ensureSharedDirectoriesExists() {
    try? fileManager.createDirectory(at: sharedRecordsDir, withIntermediateDirectories: true)
  }

  func listRecordURLs() -> [URL] {
    guard
      let urls = try? fileManager.contentsOfDirectory(
        at: recordsDir, includingPropertiesForKeys: nil)
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

  func getSharedRecordedVideoURL(_ recordedVideoURL: URL) -> URL {
    let filename = recordedVideoURL.lastPathComponent
    return sharedRecordsDir.appending(path: filename, directoryHint: .notDirectory)
  }
}
