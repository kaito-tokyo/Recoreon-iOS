import AVFoundation
import Foundation
import RealtimeMediaWriter
import XCTest

private let appSampleRate = 44_100
private let height = 1920
private let frameRate = 60
private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

final class FragmentedAudioWriterTests: XCTestCase {

  func testCreateAppAudioStream() async throws {
    let sampleRate = appSampleRate
    let name = "FragmentedAudioWriterTests_testCreateAppAudioStream"
    let outputDirectoryURL = documentsURL.appending(path: name, directoryHint: .isDirectory)
    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL,
      withIntermediateDirectories: true
    )

    print("Output directory is \(outputDirectoryURL.path())")

    let dummyAppAudioGenerator = try DummyAudioGenerator(
      sampleRate: sampleRate, initialPTS: CMTime.zero)

    let audioWriter = try FragmentedAudioWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: "\(name)-app",
      sampleRate: sampleRate,
      sourceFormatHint: dummyAppAudioGenerator.formatDesc
    )

    for _ in 0..<sampleRate * 10 / 1024 {
      var err: OSStatus
      let audioFrame = dummyAppAudioGenerator.generateNextAudioFrame()

      var sampleTiming = CMSampleTimingInfo(
        duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
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
        sampleCount: CMItemCount(audioFrame.audioBufferList.mBuffers.mDataByteSize / 4),
        sampleTimingEntryCount: 1,
        sampleTimingArray: &sampleTiming,
        sampleSizeEntryCount: 0,
        sampleSizeArray: nil,
        sampleBufferOut: &sampleBufferOut
      )
      guard err == noErr, let sampleBuffer = sampleBufferOut else {
        XCTFail("Could not create CMSampleBuffer for AudioBufferList!")
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
      guard err == noErr else {
        XCTFail("Could not load AudioBufferList to CMSampleBuffer!")
        return
      }

      try audioWriter.send(sampleBuffer: sampleBuffer)

      try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / sampleRate))
    }

    try await audioWriter.close()
  }
}
