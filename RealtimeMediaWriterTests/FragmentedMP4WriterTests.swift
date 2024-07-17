import CoreMedia
import RealtimeMediaWriter
import XCTest

final class FragmentedMP4WriterTests: XCTestCase {

  func testVideoOnly() async throws {
    let width = 888
    let height = 1920
    let frameRate = 60

    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let outputDirectoryURL = documentsURL.appending(path: "videoOnly", directoryHint: .isDirectory)

    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL, withIntermediateDirectories: true)

    print("Output directory is \(outputDirectoryURL.path())")

    let videoFormatDesc = try CMFormatDescription(
      videoCodecType: .h264, width: width, height: height)
    let writer = try FragmentedMP4Writer(
      outputDirectoryURL: outputDirectoryURL, outputFilePrefix: "Recoreon0T0", frameRate: frameRate, videoFormatDesc: videoFormatDesc
    )

    let initialPTS = CMTime(value: 100, timescale: CMTimeScale(frameRate))

    let dummyVideoGenerator = try DummyVideoGenerator(
      width: width, height: height, frameRate: frameRate,
      initialPTS: initialPTS)

    let videoTranscoder = try RealtimeVideoTranscoder(width: width, height: height)

    for _ in 0..<1200 {
      let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
      videoTranscoder.sendImageBuffer(
        imageBuffer: videoFrame.pixelBuffer,
        pts: videoFrame.pts
      ) { (status, _, sbuf) in
        guard status == noErr, let sampleBuffer = sbuf else { return }
        try? writer.sendVideoSampleBuffer(sampleBuffer: sampleBuffer)
      }
    }

    videoTranscoder.close()
    try await writer.close()
  }

}
