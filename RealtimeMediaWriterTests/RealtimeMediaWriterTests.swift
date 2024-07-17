import CoreMedia
import RealtimeMediaWriter
import VideoToolbox
import XCTest

final class RealtimeMediaWriterTests: XCTestCase {

  let hundredMilliSeconds: UInt64 = 100_000_000

  func sendFrameToTranscoder(videoTranscoder: RealtimeVideoTranscoder, videoFrame: VideoFrame) async
    -> (OSStatus, VTEncodeInfoFlags, CMSampleBuffer?)
  {
    return await withCheckedContinuation { continuation in
      videoTranscoder.sendImageBuffer(
        imageBuffer: videoFrame.pixelBuffer, pts: videoFrame.pts
      ) {
        (status, infoFlags, sbuf) in continuation.resume(returning: (status, infoFlags, sbuf))
      }
    }
  }

  func testRealtimeVideoTranscoderSendImageBuffer() async throws {
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
      for i in 0..<5 {
        group.addTask {
          let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
          let (_, _, sbuf) = await self.sendFrameToTranscoder(videoTranscoder: videoTranscoder, videoFrame: videoFrame)
          XCTAssert(sbuf?.presentationTimeStamp == CMTime(value: 100 + CMTimeValue(i), timescale: CMTimeScale(frameRate)))
          return
        }

        try await Task.sleep(nanoseconds: 100_000_000)
      }

      videoTranscoder.close()
    }
  }
}
