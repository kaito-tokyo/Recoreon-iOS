struct ScreenRecordEntry: Identifiable, Hashable {
  let url: URL
  let encodedVideoCollection: EncodedVideoCollection
  let size: UInt64
  let creationDate: Date
  let noteEntries: [ScreenRecordNoteEntry]

  var id: URL { url }
}
