import Foundation

struct ScreenRecordEntry: Identifiable, Hashable {
  let url: URL
  let size: UInt64
  let creationDate: Date
  let summaryBody: String

  var id: URL { url }
  var recordID: String { url.lastPathComponent }
}
