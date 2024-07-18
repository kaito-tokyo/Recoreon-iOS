import AVFoundation
import CoreMedia
import RealtimeMediaWriter
import VideoToolbox
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
      AVSampleRateKey: 48_000,
      AVNumberOfChannelsKey: 2,
      AVEncoderBitRateKey: 320_000,
    ]
    let writer = try FragmentedMP4Writer(
      outputDirectoryURL: outputDirectoryURL, outputFilePrefix: "Recoreon0T0", frameRate: frameRate,
      videoOutputSettings: videoOutputSettings, appAudioOutputSettings: audioOutputSettings
    )

    let initialPTS = CMTime.zero

    let dummyVideoGenerator = try DummyVideoGenerator(
      width: width, height: height, frameRate: frameRate, initialPTS: initialPTS)

    let dummyAudioGenerator = try DummyAudioGenerator(sampleRate: 48_000, initialPTS: initialPTS)

    func send(videoFrame: VideoFrame) throws {
      let videoFrame = try dummyVideoGenerator.generateNextVideoFrame()

      var sampleTiming = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: CMTimeScale(frameRate)),
        presentationTimeStamp: videoFrame.pts,
        decodeTimeStamp: .invalid
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
    }

    func send(audioFrame: AudioFrame) throws {
      var err: OSStatus

      var sampleTiming = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 48_000),
        presentationTimeStamp: audioFrame.pts,
        decodeTimeStamp: .invalid
      )

      var sampleBufferOut: CMSampleBuffer?
      err = CMSampleBufferCreate(
        allocator: kCFAllocatorDefault,
        dataBuffer: nil,
        dataReady: false,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: dummyAudioGenerator.formatDesc,
        sampleCount: Int(audioFrame.audioBufferList.mBuffers.mDataByteSize / 4),
        sampleTimingEntryCount: 1,
        sampleTimingArray: &sampleTiming,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBufferOut
      )
      guard err == noErr, let sampleBuffer = sampleBufferOut else {
        XCTFail()
        return
      }

      var audioBufferList = audioFrame.audioBufferList

      err = CMSampleBufferSetDataBufferFromAudioBufferList(
        sampleBuffer,
        blockBufferAllocator: kCFAllocatorDefault,
        blockBufferMemoryAllocator: kCFAllocatorDefault,
        flags: 0,
        bufferList: &audioBufferList
      )

      try writer.sendAppAudio(sampleBuffer: sampleBuffer)
    }

    var videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
    var audioFrame = dummyAudioGenerator.generateNextAudioFrame()
    while true {
      if CMTimeCompare(videoFrame.pts, audioFrame.pts) <= 0 {
        try send(videoFrame: videoFrame)
        videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / frameRate))
      } else {
        try send(audioFrame: audioFrame)
        audioFrame = dummyAudioGenerator.generateNextAudioFrame()
        try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 48_000))
      }

      if videoFrame.pts.seconds > 5.0 {
        break
      }
    }

    try await writer.close()
  }

}
