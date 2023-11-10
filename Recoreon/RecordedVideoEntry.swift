struct RecordedVideoEntry: Identifiable {
  let url: URL

  var id: URL { url }
}
