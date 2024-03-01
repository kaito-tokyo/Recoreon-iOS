struct RecordNoteEntry: Identifiable, Hashable {
  let url: URL
  let body: String
  var shortName: String {
    let components = url.lastPathComponent.split(separator: "-", maxSplits: 1)
    if components.count == 2 {
      return String(components[1])
    } else {
      return ""
    }
  }

  var id: URL { url }
}