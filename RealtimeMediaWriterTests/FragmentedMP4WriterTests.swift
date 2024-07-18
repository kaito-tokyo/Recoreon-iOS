import CoreMedia
import RealtimeMediaWriter
import XCTest
import AVFoundation
import VideoToolbox

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

    let videoOutputSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
      AVVideoCompressionPropertiesKey: [
        kVTCompressionPropertyKey_MaxKeyFrameInterval: frameRate * 2,
        kVTCompressionPropertyKey_AverageBitRate: 8_000_000,
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_4_2,
        kVTCompressionPropertyKey_RealTime: true,
        kVTCompressionPropertyKey_ExpectedFrameRate: frameRate,
      ],
    ]
    let audioOutputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: kRealTimeAudioTranscoderInputASBD.mSampleRate,
      AVNumberOfChannelsKey: kRealTimeAudioTranscoderInputASBD.mChannelsPerFrame,
      AVEncoderBitRateKey: 320_000,
    ]
    let writer = try FragmentedMP4Writer(
      outputDirectoryURL: outputDirectoryURL, outputFilePrefix: "Recoreon0T0", frameRate: frameRate,
      videoOutputSettings: videoOutputSettings, appAudioOutputSettings: audioOutputSettings
    )

    let initialPTS = CMTime(value: 100, timescale: CMTimeScale(frameRate))

    let dummyVideoGenerator = try DummyVideoGenerator(
      width: width, height: height, frameRate: frameRate,
      initialPTS: initialPTS)

    let dummyAudioGenerator = DummyAudioGenerator(sampleRate: 48_000, initialPTS: CMTime(value: 80_000, timescale: 48_000))

    for _ in 0..<10 {
      for _ in 0..<60 {
        let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()

        var sampleTiming = CMSampleTimingInfo(
          duration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
          presentationTimeStamp: videoFrame.pts,
          decodeTimeStamp: videoFrame.pts
        )
        var sampleBufferOut: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
          allocator: kCFAllocatorDefault,
          imageBuffer: videoFrame.pixelBuffer,
          dataReady: true,
          makeDataReadyCallback: nil,
          refcon: nil,
          formatDescription: try CMVideoFormatDescription(imageBuffer: videoFrame.pixelBuffer),
          sampleTiming: &sampleTiming,
          sampleBufferOut: &sampleBufferOut
        )
        guard let sampleBuffer = sampleBufferOut else {
          XCTFail()
          return
        }

        try? writer.sendVideoSampleBuffer(sampleBuffer: sampleBuffer)

        try await Task.sleep(nanoseconds: UInt64(1e9 / Double(frameRate)))
      }

      for _ in 0..<1 {
        let audioFrame = dummyAudioGenerator.generateNextAudioFrame()

        var sampleTiming = CMSampleTimingInfo(
          duration: CMTime(value: CMTimeValue(audioFrame.audioBufferList.mBuffers.mDataByteSize / 4), timescale: 48_000),
          presentationTimeStamp: audioFrame.pts,
          decodeTimeStamp: audioFrame.pts
        )
        var sampleBufferOut: CMSampleBuffer?
        CMSampleBufferCreate(
          allocator: kCFAllocatorDefault,
          dataBuffer: nil,
          dataReady: false,
          makeDataReadyCallback: nil,
          refcon: nil,
          formatDescription: try CMFormatDescription(audioStreamBasicDescription: kRealTimeAudioTranscoderOutputASBD),
          sampleCount: Int(audioFrame.audioBufferList.mBuffers.mDataByteSize / 4),
          sampleTimingEntryCount: 1,
          sampleTimingArray: &sampleTiming,
          sampleSizeEntryCount: 0,
          sampleSizeArray: nil,
          sampleBufferOut: &sampleBufferOut
        )

      }
    }

    try await writer.close()
  }

}
