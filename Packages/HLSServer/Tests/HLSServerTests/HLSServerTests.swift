import NIOCore
import NIOHTTP1
import NIOPosix
import XCTest

@testable import HLSServer

final class HLSServerTests: XCTestCase {
  func testExample() async throws {
    let fileManager = FileManager.default

    let htdocsDirectory = fileManager.temporaryDirectory.appending(
      path: "htdocs",
      directoryHint: .isDirectory
    )
    try? fileManager.removeItem(at: htdocsDirectory)
    try fileManager.createDirectory(at: htdocsDirectory, withIntermediateDirectories: true)

    let testFileName = "text.txt"
    let testFileContent = "test"

    try testFileContent.write(
      to: htdocsDirectory.appending(path: testFileName, directoryHint: .notDirectory),
      atomically: true,
      encoding: .utf8
    )

    let host = "::1"
    let server = try HLSServer(htdocs: htdocsDirectory.path(percentEncoded: false), host: host)
    let url = URL(string: "http://[\(host)]:\(server.port)/\(testFileName)")!
    let (data, response) = try await URLSession.shared.data(from: url)

    XCTAssert(String(decoding: data, as: UTF8.self) == testFileContent)
  }
}
