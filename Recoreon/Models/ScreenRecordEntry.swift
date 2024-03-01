struct ScreenRecordEntry: Identifiable, Hashable {
  let url: URL
  let size: UInt64
  let creationDate: Date

  var id: URL { url }
}
