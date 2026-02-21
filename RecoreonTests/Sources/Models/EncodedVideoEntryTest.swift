import XCTest

@testable import Recoreon

final class EncodedVideoEntryTest: XCTestCase {
  let url = URL(string: "url")!
  let encodingPreset: EncodingPreset = .lowQuality

  func testIdentifiable() throws {
    let encodedVideoEntry = EncodedVideoEntry(url: url, preset: encodingPreset)
    XCTAssert(encodedVideoEntry.id == url)
  }

  func testHashable() throws {
    let encodedVideoEntry = EncodedVideoEntry(url: url, preset: encodingPreset)
    var hasher = Hasher()
    encodedVideoEntry.hash(into: &hasher)
    hasher.finalize()
  }
}
