class RecoreonPaths {
  let appGroupIdentifier = "group.com.github.umireon.Recoreon"

  private let fileManager = FileManager.default

  func appGroupDir() -> URL? {
    return FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier)
  }

  func documentsDir() -> URL? {
    return appGroupDir()?.appending(path: "Documents", directoryHint: .isDirectory)
  }

  func recordsDir() -> URL? {
    return documentsDir()?.appending(path: "Records", directoryHint: .isDirectory)
  }

  func libraryDir() -> URL? {
    return appGroupDir()?.appending(path: "Library", directoryHint: .isDirectory)
  }

  func thumbnailsDir() -> URL? {
    return libraryDir()?.appending(path: "Thumbnails", directoryHint: .isDirectory)
  }

  func encodedVideosDir() -> URL? {
    return libraryDir()?.appending(path: "EncodedVideos", directoryHint: .isDirectory)
  }

  func ensureRecordsDirExists() {
    guard let recordsDir = recordsDir() else {
      print("Could not obtain the records directory path!")
      return
    }
    do {
      try fileManager.createDirectory(at: recordsDir, withIntermediateDirectories: true)
    } catch {
      print("Could not create the records directory!")
    }
  }

  func ensureThumbnailsDirExists() {
    guard let thumbnailsDir = thumbnailsDir() else {
      print("Could not obtain the thumbnails directory path!")
      return
    }
    do {
      try fileManager.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    } catch {
      print("Could not create the thumbnails directory!")
    }
  }

  func ensureEncodedVideosDirExists() {
    guard let encodedVideosDir = encodedVideosDir() else {
      print("Could not obtain the encoded videos directory path!")
      return
    }
    do {
      try fileManager.createDirectory(at: encodedVideosDir, withIntermediateDirectories: true)
    } catch {
      print("Could not create the encoded videos directory!")
    }
  }

  func listRecordURLs() -> [URL] {
    guard let recordsDir = recordsDir() else { return [] }
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: recordsDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return urls.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }

  func listMkvRecordURLs() -> [URL] {
    listRecordURLs().filter { $0.pathExtension == "mkv" }
  }

  func getThumbnailURL(videoURL: URL) -> URL? {
    let thumbFilaname = videoURL.deletingPathExtension().appendingPathExtension("jpg")
      .lastPathComponent
    guard let thumbnailsDir = thumbnailsDir() else { return nil }
    return thumbnailsDir.appending(path: thumbFilaname, directoryHint: .notDirectory)
  }

  func getEncodedVideoURL(videoURL: URL, suffix: String, ext: String = "mp4") -> URL? {
    let filename = videoURL.deletingPathExtension().lastPathComponent + suffix + "." + ext
    guard let encodedVideosDir = encodedVideosDir() else { return nil }
    return encodedVideosDir.appending(path: filename, directoryHint: .notDirectory)
  }
}
