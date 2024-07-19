import AVFoundation
import CoreAudio
import Foundation
import FragmentedScreenRecordWriter
import XCTest

fileprivate let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

final class AudioResamplerTests: XCTestCase {
  private func getOutputDirectoryURL(name: String) throws -> URL {
    let outputDirectoryURL = documentsURL.appending(path: name, directoryHint: .isDirectory)

    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL,
      withIntermediateDirectories: true
    )

    return outputDirectoryURL
  }

  func send(
    audioTranscoderResult: RealtimeAudioTranscoderResult,
    sampleRate: Int,
    pts: CMTime,
    formatDesc: CMFormatDescription,
    writer: FragmentedAudioWriter
  ) throws {
    var sampleTiming = CMSampleTimingInfo(
      duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
      presentationTimeStamp: pts,
      decodeTimeStamp: .invalid
    )

    var sampleBufferOut: CMSampleBuffer?
    let err1 = CMSampleBufferCreate(
      allocator: kCFAllocatorDefault,
      dataBuffer: nil,
      dataReady: false,
      makeDataReadyCallback: nil,
      refcon: nil,
      formatDescription: formatDesc,
      sampleCount: Int(audioTranscoderResult.audioBufferList.mNumberBuffers),
      sampleTimingEntryCount: 1,
      sampleTimingArray: &sampleTiming,
      sampleSizeEntryCount: 0,
      sampleSizeArray: nil,
      sampleBufferOut: &sampleBufferOut
    )
    guard err1 == noErr, let sampleBuffer = sampleBufferOut else {
      XCTFail("error")
      return
    }

    var audioBufferList = audioTranscoderResult.audioBufferList
    _ = CMSampleBufferSetDataBufferFromAudioBufferList(
      sampleBuffer,
      blockBufferAllocator: kCFAllocatorDefault,
      blockBufferMemoryAllocator: kCFAllocatorDefault,
      flags: 0,
      bufferList: &audioBufferList
    )

    try writer.send(sampleBuffer: sampleBuffer)
  }

  func testCreate48000Audio() async throws {
    let sampleRate = 48000

    let name = "AudioResamplerTests_testCreate48000Audio"
    let outputDirectoryURL = try getOutputDirectoryURL(name: name)
    print("Output directory is \(outputDirectoryURL.path())")

    let inputAudioStreamBasicDescription = AudioStreamBasicDescription(
      mSampleRate: Float64(sampleRate),
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
      mBytesPerPacket: 8,
      mFramesPerPacket: 1,
      mBytesPerFrame: 8,
      mChannelsPerFrame: 2,
      mBitsPerChannel: 32,
      mReserved: 0
    )

    let outputAudioStreamBasicDescription = AudioStreamBasicDescription(
      mSampleRate: Float64(sampleRate),
      mFormatID: kAudioFormatMPEG4AAC,
      mFormatFlags: 0,
      mBytesPerPacket: 0,
      mFramesPerPacket: 1024,
      mBytesPerFrame: 0,
      mChannelsPerFrame: 2,
      mBitsPerChannel: 0,
      mReserved: 0
    )

    let outputFormatDesc = try CMFormatDescription(
      audioStreamBasicDescription: outputAudioStreamBasicDescription
    )

    let audioTranscoder = try RealtimeAudioTranscoder(
      inputAudioStreamBasicDescription: inputAudioStreamBasicDescription,
      outputAudioStreamBasicDescription: outputAudioStreamBasicDescription
    )

    let audioResampler = try AudioResampler(outputSampleRate: sampleRate)

    let dummyAudioGenerator = try DummyAudioGenerator(
      sampleRate: sampleRate,
      initialPTS: CMTime.zero
    )

    let audioWriter = try FragmentedAudioWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: name,
      sampleRate: sampleRate,
      sourceFormatHint: outputFormatDesc
    )

    for _ in 0..<sampleRate * 10 / 1024 {
      let dummyAudioFrame = dummyAudioGenerator.generateNextAudioFrame()

      guard let stereoInt16Buffer = dummyAudioFrame.audioBufferList.mBuffers.mData?.assumingMemoryBound(to: Int16.self) else {
        XCTFail("error")
        return
      }
      let numSamples = Int(dummyAudioFrame.audioBufferList.mBuffers.mDataByteSize / 4)
      try audioResampler.append(
        stereoInt16Buffer: stereoInt16Buffer,
        numSamples: numSamples,
        inputSampleRate: sampleRate,
        pts: dummyAudioFrame.pts
      )
      let audioResamplerFrame = audioResampler.getCurrentFrame()

      let inputBuffer = audioResamplerFrame.data
      let numInputSamples = audioResamplerFrame.numSamples
      let audioTranscoderResult = try audioTranscoder.send(inputBuffer: inputBuffer, numInputSamples: numInputSamples)

      let pts = audioResamplerFrame.pts
      try send(
        audioTranscoderResult: audioTranscoderResult,
        sampleRate: sampleRate,
        pts: pts,
        formatDesc: outputFormatDesc,
        writer: audioWriter
      )

      try await Task.sleep(nanoseconds: UInt64(1_000_000_000 / sampleRate))
    }

    try await audioWriter.close()

    _ = try audioWriter.writeIndexPlaylist()
  }
}
