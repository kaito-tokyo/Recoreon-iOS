import AVFoundation
import Foundation
import RealtimeMediaWriter
import XCTest

fileprivate let width = 888
fileprivate let height = 1920
fileprivate let frameRate = 60
fileprivate let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

final class FragmentedVideoWriterTests: XCTestCase {

  func testCreateVideoStream() async throws {
    let name = "FragmentedVideoWriterTests_testCreateVideoStream"
    let outputDirectoryURL = documentsURL.appending(path: name, directoryHint: .isDirectory)
    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL, withIntermediateDirectories: true)

    print("Output directory is \(outputDirectoryURL.path())")

    let videoWriter = try FragmentedVideoWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: name,
      frameRate: frameRate,
      sourceFormatHint: CMFormatDescription(
        videoCodecType: .h264,
        width: width,
        height: height
      )
    )

    let videoTranscoder = try RealtimeVideoTranscoder(width: width, height: height)

    let dummyVideoGenerator = try DummyVideoGenerator(
      width: width,
      height: height,
      frameRate: frameRate,
      initialPTS: CMTime.zero
    )

    for _ in 0..<600 {
      let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()

      videoTranscoder.send(
        imageBuffer: videoFrame.pixelBuffer,
        pts: videoFrame.pts
      ) { (_, _, sbuf) in
        try? videoWriter.send(sampleBuffer: sbuf!)
      }

      try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / frameRate))
    }

    try await Task.sleep(nanoseconds: 1_000_000)

    try await videoWriter.close()
  }
}
