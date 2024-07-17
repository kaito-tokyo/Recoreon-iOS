import CoreMedia
import RealtimeMediaWriter
import VideoToolbox
import XCTest

final class RealtimeVideoTranscoderTests: XCTestCase {

  let hundredMilliSeconds: UInt64 = 100_000_000

  func sendFrameToTranscoder(
    videoTranscoder: RealtimeVideoTranscoder, videoFrame: VideoFrame
  ) async -> CMSampleBuffer? {
    return await withCheckedContinuation { continuation in
      videoTranscoder.sendImageBuffer(
        imageBuffer: videoFrame.pixelBuffer, pts: videoFrame.pts
      ) { (_, _, sbuf) in
        continuation.resume(returning: sbuf)
      }
    }
  }

  func testSendImageBuffer() async throws {
    let width = 888
    let height = 1920
    let bytesPerRow = 1024
    let frameRate = 60
    let initialPTS = CMTime(value: 100, timescale: CMTimeScale(frameRate))

    let videoTranscoder = try RealtimeVideoTranscoder(width: width, height: height)

    let dummyVideoGenerator = DummyVideoGenerator(
      width: width, height: height, bytesPerRow: bytesPerRow, frameRate: frameRate,
      initialPTS: initialPTS)

    try await withThrowingTaskGroup(of: Void.self) { [self] group throws in
      for _ in 0..<5 {
        group.addTask {
          let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
          let sbuf = await self.sendFrameToTranscoder(
            videoTranscoder: videoTranscoder, videoFrame: videoFrame)
          XCTAssert(sbuf?.presentationTimeStamp == videoFrame.pts)
        }

        try await Task.sleep(nanoseconds: 100_000_000)
      }

      videoTranscoder.close()
    }
  }
}
