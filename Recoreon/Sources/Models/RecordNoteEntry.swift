import Foundation

struct RecordNoteEntry: Identifiable, Hashable {
  let url: URL
  let body: String

  var id: URL { url }
}
