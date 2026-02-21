import Foundation

struct EncodedVideoEntry: Identifiable, Hashable {
  let url: URL
  let preset: EncodingPreset

  var id: URL { url }

  static let invalid = EncodedVideoEntry(url: URL(string: "invalid")!, preset: .lowQuality)
}
