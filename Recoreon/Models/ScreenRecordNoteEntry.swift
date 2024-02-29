struct ScreenRecordNoteEntry: Identifiable, Hashable {
  let url: URL
  let content: String

  var id: URL { url }
}
