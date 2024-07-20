import Foundation

public struct RecoreonPathService {
  private let fileManager: FileManager

  private let appGroupsDir: URL
  private let appGroupsDocumentsDir: URL
  private let appGroupsRecordsDir: URL
  private let appGroupsFragmentedRecordsDir: URL
  private let libraryDir: URL
  private let previewVideosDir: URL
  private let encodedVideosDir: URL
  private let documentsDir: URL
  private let recordsDir: URL
  private let recordNotesDir: URL

  public init(fileManager: FileManager) {
    self.fileManager = fileManager
    appGroupsDir = fileManager.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupsIdentifier)!
    appGroupsDocumentsDir = appGroupsDir.appending(
      component: "Documents", directoryHint: .isDirectory)
    appGroupsFragmentedRecordsDir = appGroupsDocumentsDir.appending(
      path: "FragmentedRecords",
      directoryHint: .isDirectory
    )
    appGroupsRecordsDir = appGroupsDocumentsDir.appending(
      path: "Records", directoryHint: .isDirectory)
    libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
    previewVideosDir = libraryDir.appending(path: "PreviewVideos", directoryHint: .isDirectory)
    encodedVideosDir = libraryDir.appending(path: "EncodedVideos", directoryHint: .isDirectory)
    documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    recordsDir = documentsDir.appending(path: "Records", directoryHint: .isDirectory)
    recordNotesDir = documentsDir.appending(path: "RecordNotes", directoryHint: .isDirectory)
  }

  public func getRecordID(screenRecordURL url: URL) -> String {
    return url.deletingPathExtension().lastPathComponent
  }

  public func mkdirp(url: URL) {
    try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
  }

  public func generateRecordID(date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current

    let recordDatetime = formatter.string(from: date)
    let recordID = "Recoreon\(recordDatetime)"
    return recordID
  }

  public func wipe() {
    try? fileManager.removeItem(at: appGroupsDocumentsDir)
    try? fileManager.removeItem(at: documentsDir)
    try? fileManager.removeItem(at: libraryDir)
  }

  public func wipeRecordNotes() {
    try? fileManager.removeItem(at: recordNotesDir)
  }

  // ScreenRecord

  public func generateAppGroupsScreenRecordURL(recordID: String, ext: String) -> URL {
    mkdirp(url: appGroupsRecordsDir)
    let appGroupScreenRecordURL = appGroupsRecordsDir.appending(
      path: "\(recordID).\(ext)", directoryHint: .notDirectory)
    return appGroupScreenRecordURL
  }

  public func generateAppGroupsFragmentedRecordURL(recordID: String) -> URL {
    let appGroupsScreenRecordDIrectoryURL = appGroupsFragmentedRecordsDir.appending(
      path: recordID,
      directoryHint: .isDirectory
    )
    mkdirp(url: appGroupsScreenRecordDIrectoryURL)
    return appGroupsScreenRecordDIrectoryURL
  }

  public func listScreenRecordURLs() -> [URL] {
    guard
      let screenRecordURLs = try? fileManager.contentsOfDirectory(
        at: appGroupsRecordsDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return screenRecordURLs.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }

  public func listFragmentedRecordURLs() -> [URL] {
    guard
      let fragmentedRecordURLs = try? fileManager.contentsOfDirectory(
        at: appGroupsFragmentedRecordsDir,
        includingPropertiesForKeys: nil
      )
    else { return [] }

    return fragmentedRecordURLs.sorted(by: {
      $0.lastPathComponent.compare($1.lastPathComponent) == .orderedAscending
    })
  }


  // RecordNote

  public func generateRecordNoteSubDirURL(screenRecordURL: URL) -> URL {
    let recordId = screenRecordURL.deletingPathExtension().lastPathComponent
    let recordNoteSubDirURL = recordNotesDir.appending(path: recordId, directoryHint: .isDirectory)
    mkdirp(url: recordNoteSubDirURL)
    return recordNoteSubDirURL
  }

  public func listRecordNoteURLs(screenRecordURL: URL) -> [URL] {
    let recordNotesSubDir = generateRecordNoteSubDirURL(screenRecordURL: screenRecordURL)
    guard
      let recordNoteURLs = try? fileManager.contentsOfDirectory(
        at: recordNotesSubDir, includingPropertiesForKeys: nil)
    else {
      return []
    }
    return recordNoteURLs.sorted(by: { lhs, rhs in
      lhs.lastPathComponent.compare(rhs.lastPathComponent) == .orderedAscending
    })
  }

  public func extractRecordNoteShortName(recordNoteURL: URL) -> String {
    let filename = recordNoteURL.deletingPathExtension().lastPathComponent
    let components = filename.split(separator: "-", maxSplits: 2)
    return String(components.last ?? "")
  }

  public func isRecordNoteURLReserved(recordNoteURL: URL) -> Bool {
    let recordNoteShortName = extractRecordNoteShortName(recordNoteURL: recordNoteURL)
    return ["summary"].contains(recordNoteShortName)
  }

  public func generateRecordNoteSubDirURL(recordID: String) -> URL {
    let subDirURL = recordNotesDir.appending(component: recordID, directoryHint: .isDirectory)
    mkdirp(url: subDirURL)
    return subDirURL
  }

  public func generateRecordNoteURL(recordID: String, shortName: String) -> URL {
    let subDirURL = generateRecordNoteSubDirURL(recordID: recordID)
    return subDirURL.appending(
      path: "\(recordID)-\(shortName).txt", directoryHint: .notDirectory)
  }

  public func generateRecordSummaryURL(recordID: String) -> URL {
    return generateRecordNoteURL(recordID: recordID, shortName: "summary")
  }

  // PreviewVideo

  public func generatePreviewVideoURL(recordID: String) -> URL {
    let ext = "mp4"
    mkdirp(url: previewVideosDir)
    let previewVideoURL = previewVideosDir.appending(
      path: "$\(recordID).\(ext)", directoryHint: .notDirectory)
    return previewVideoURL
  }

  // EncodedVideo

  public func generateEncodedVideoURL(recordID: String, presetName: String) -> URL {
    let ext = "mp4"
    mkdirp(url: encodedVideosDir)
    return encodedVideosDir.appending(
      path: "\(recordID)-\(presetName).\(ext)", directoryHint: .notDirectory)
  }
}
