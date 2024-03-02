struct RecordNoteEntry: Identifiable, Hashable {
  let url: URL
  let body: String

  var filename: String {
    url.lastPathComponent
  }

  var id: URL { url }
}
