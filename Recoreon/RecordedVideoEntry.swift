struct RecordedVideoEntry: Identifiable, Hashable {
  let url: URL
  let encodedVideoCollection: EncodedVideoCollection
  let size: UInt64
  let creationDate: Date

  var id: URL { url }
}
