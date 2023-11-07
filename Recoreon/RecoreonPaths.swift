class RecoreonPaths {
    let appGroupIdentifier = "group.com.github.umireon.Recoreon"
    
    func appGroupDir() -> URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
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
    
    func ensureDirectoriesExists() {
        guard let recordsDir = recordsDir() else { return }
        guard let thumbnailsDir = thumbnailsDir() else { return }
        guard let encodedVideosDir = encodedVideosDir() else { return }
        try! FileManager.default.createDirectory(at: recordsDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: encodedVideosDir, withIntermediateDirectories: true)
    }
    
    func listRecordURLs() -> [URL] {
        guard let recordsDir = recordsDir() else { return [] }
        guard let urls = try? FileManager.default.contentsOfDirectory(at: recordsDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls
    }
    
    func listMkvRecordURLs() -> [URL] {
        listRecordURLs().filter { $0.pathExtension == "mkv" }
    }
    
    func getThumbnailURL(videoURL: URL) -> URL? {
        let thumbFilaname = videoURL.deletingPathExtension().appendingPathExtension("jpg").lastPathComponent
        guard let thumbnailsDir = thumbnailsDir() else { return nil }
        return thumbnailsDir.appending(path: thumbFilaname, directoryHint: .notDirectory)
    }
    
    func getEncodedVideoURL(videoURL: URL, suffix: String, ext: String = "mp4") -> URL? {
        let filename = videoURL.deletingPathExtension().lastPathComponent + suffix + "." + ext
        guard let encodedVideosDir = encodedVideosDir() else { return nil }
        return encodedVideosDir.appending(path: filename, directoryHint: .notDirectory)
    }
}
