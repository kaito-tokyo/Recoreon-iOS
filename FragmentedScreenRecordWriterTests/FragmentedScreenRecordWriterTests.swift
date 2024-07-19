import AVFoundation
import CoreMedia
import FragmentedScreenRecordWriter
import VideoToolbox
import XCTest

final class FragmentedScreenRecordWriterTests: XCTestCase {
  // swiftlint:disable function_body_length
  func testCreateScreenRecord() async throws {
    let name = "FragmentedScreenRecordWriterTests_testCreateScreenRecord"
    let width = 888
    let height = 1920
    let frameRate = 60
    let initialPTS = CMTime.zero

    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let outputDirectoryURL = documentsURL.appending(path: name, directoryHint: .isDirectory)
    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL,
      withIntermediateDirectories: true
    )
    print("Output directory is \(outputDirectoryURL.path())")

    let screenRecordWriter = try FragmentedScreenRecordWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: name,
      width: width,
      height: height,
      frameRate: frameRate
    )

    let dummyVideoGenerator = try DummyVideoGenerator(
      width: width,
      height: height,
      frameRate: frameRate,
      initialPTS: initialPTS
    )

    let dummyAppAudioGenerator = try DummyAudioGenerator(sampleRate: 44_100, initialPTS: initialPTS)
    let dummyMicAudioGenerator = try DummyAudioGenerator(sampleRate: 48_000, initialPTS: initialPTS)

    func send(videoFrame: DummyVideoGeneratorFrame) throws {
      try screenRecordWriter.sendVideo(imageBuffer: videoFrame.pixelBuffer, pts: videoFrame.pts)
    }

    func send(appAudioFrame audioFrame: DummyAudioGeneratorFrame) throws {
      var err: OSStatus

      var sampleTiming = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: 44_100),
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
        formatDescription: dummyAppAudioGenerator.formatDesc,
        sampleCount: Int(audioFrame.audioBufferList.mBuffers.mDataByteSize / 4),
        sampleTimingEntryCount: 1,
        sampleTimingArray: &sampleTiming,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBufferOut
      )
      guard err == noErr, let sampleBuffer = sampleBufferOut else {
        XCTFail("error")
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

      try screenRecordWriter.sendAppAudio(sampleBuffer: sampleBuffer)
    }

    func send(micAudioFrame audioFrame: DummyAudioGeneratorFrame) throws {
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
        formatDescription: dummyMicAudioGenerator.formatDesc,
        sampleCount: Int(audioFrame.audioBufferList.mBuffers.mDataByteSize / 4),
        sampleTimingEntryCount: 1,
        sampleTimingArray: &sampleTiming,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBufferOut
      )
      guard err == noErr, let sampleBuffer = sampleBufferOut else {
        XCTFail("error")
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

      try screenRecordWriter.sendMicAudio(sampleBuffer: sampleBuffer)
    }

    var videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
    var appAudioFrame = dummyAppAudioGenerator.generateNextAudioFrame()
    var micAudioFrame = dummyMicAudioGenerator.generateNextAudioFrame()
    while true {
      if CMTimeCompare(videoFrame.pts, appAudioFrame.pts) > 0 {
        if CMTimeCompare(appAudioFrame.pts, micAudioFrame.pts) > 0 {
          try send(micAudioFrame: micAudioFrame)
          micAudioFrame = dummyMicAudioGenerator.generateNextAudioFrame()
          try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 48_000))
        } else {
          try send(appAudioFrame: appAudioFrame)
          appAudioFrame = dummyAppAudioGenerator.generateNextAudioFrame()
          try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 44_100))
        }
      } else {
        if CMTimeCompare(videoFrame.pts, micAudioFrame.pts) > 0 {
          try send(micAudioFrame: micAudioFrame)
          micAudioFrame = dummyMicAudioGenerator.generateNextAudioFrame()
          try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / 48_000))
        } else {
          try send(videoFrame: videoFrame)
          videoFrame = try dummyVideoGenerator.generateNextVideoFrame()
          try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / frameRate))
        }
      }

      if videoFrame.pts.seconds >= 5.0 {
        break
      }
    }

    try await screenRecordWriter.close()
    try screenRecordWriter.writeMasterPlaylist()
  }
  // swiftlint:enable function_body_length

}
