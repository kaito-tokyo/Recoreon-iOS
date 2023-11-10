struct RecordedVideoEntry: Identifiable, Hashable {
  let url: URL
  let encodedVideoCollection: EncodedVideoCollection

  var id: URL { url }
}
