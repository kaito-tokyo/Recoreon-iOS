import CoreMedia
import RealtimeMediaWriter
import XCTest

final class FragmentedMP4WriterTests: XCTestCase {

  func testVideoOnly() async throws {
    let width = 888
    let height = 1920
    let frameRate = 60

    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let outputURL = documentsURL.appending(path: "videoOnly.mp4")
    try? FileManager.default.removeItem(at: outputURL)

    let videoFormatDesc = try CMFormatDescription(
      videoCodecType: .h264, width: width, height: height)
    let writer = try FragmentedMP4Writer(
      outputURL: outputURL, frameRate: frameRate, videoFormatDesc: videoFormatDesc)

    let initialPTS = CMTime(value: 100, timescale: CMTimeScale(frameRate))

    let dummyVideoGenerator = try DummyVideoGenerator(
      width: width, height: height, frameRate: frameRate,
      initialPTS: initialPTS)

    let videoTranscoder = try RealtimeVideoTranscoder(width: width, height: height)

    for _ in 0..<120 {
      let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
      videoTranscoder.sendImageBuffer(imageBuffer: videoFrame.pixelBuffer, pts: videoFrame.pts) {
        (status, infoFlags, sbuf) in
        guard status == noErr, let sampleBuffer = sbuf else { return }
        try! writer.sendVideoSampleBuffer(sampleBuffer: sampleBuffer)
      }
    }

    videoTranscoder.close()
    try await writer.close()
  }

}
