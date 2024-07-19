import AVFoundation
import CoreAudio
import Foundation
import FragmentedScreenRecordWriter
import XCTest

private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

// swiftlint:disable function_body_length
final class AudioResamplerTests: XCTestCase {
  func getOutputDirectoryURL(name: String) throws -> URL {
    let outputDirectoryURL = documentsURL.appending(path: name)

    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL,
      withIntermediateDirectories: true
    )

    return outputDirectoryURL
  }

  func testAsIs() async throws {
    try await run(
      name: "AudioResamplerTests_testAsIs",
      inputSampleRate: 48_000,
      outputSampleRate: 48_000
    )
  }

  func testUpsamplingBy2() async throws {
    try await run(
      name: "AudioResamplerTests_testUpsamplingBy2",
      inputSampleRate: 24_000,
      outputSampleRate: 48_000
    )
  }

  func testUpsamplingBy6() async throws {
    try await run(
      name: "AudioResamplerTests_testUpsamplingBy6",
      inputSampleRate: 8_000,
      outputSampleRate: 48_000
    )
  }

  private func run(name: String, inputSampleRate: Int, outputSampleRate: Int) async throws {
    let outputDirectoryURL = try getOutputDirectoryURL(name: name)
    print("Output directory is \(outputDirectoryURL.path())")

    let inputAudioStreamBasicDescription = AudioStreamBasicDescription(
      mSampleRate: Float64(outputSampleRate),
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
      mSampleRate: Float64(outputSampleRate),
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

    let audioWriter = try FragmentedAudioWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: name,
      sampleRate: outputSampleRate,
      sourceFormatHint: outputFormatDesc
    )

    let audioTranscoder = try RealtimeAudioTranscoder(
      inputAudioStreamBasicDescription: inputAudioStreamBasicDescription,
      outputAudioStreamBasicDescription: outputAudioStreamBasicDescription
    )

    let audioResampler = try AudioResampler(outputSampleRate: outputSampleRate)

    let dummyAppAudioGenerator = try DummyAudioGenerator(
      sampleRate: inputSampleRate,
      initialPTS: CMTime.zero
    )

    for _ in 0..<inputSampleRate * 10 / 1024 {
      let dummyAudioFrame = dummyAppAudioGenerator.generateNextAudioFrame()

      try audioResampler.append(
        stereoInt16Buffer: dummyAudioFrame.data,
        numSamples: Int(dummyAudioFrame.audioBufferList.mBuffers.mDataByteSize / 4),
        inputSampleRate: inputSampleRate,
        pts: dummyAudioFrame.pts
      )
      let audioResamplerFrame = audioResampler.getCurrentFrame()

      let numInputSamples = audioResamplerFrame.numSamples
      let audioTranscoderResult = try audioTranscoder.send(
        inputBuffer: audioResamplerFrame.data,
        numInputSamples: numInputSamples
      )
      var audioBufferList = audioTranscoderResult.audioBufferList

      var sampleBufferOut: CMSampleBuffer?
      let err1 = CMAudioSampleBufferCreateWithPacketDescriptions(
        allocator: kCFAllocatorDefault,
        dataBuffer: nil,
        dataReady: false,
        makeDataReadyCallback: nil,
        refcon: nil,
        formatDescription: outputFormatDesc,
        sampleCount: audioTranscoderResult.numPackets,
        presentationTimeStamp: dummyAudioFrame.pts,
        packetDescriptions: audioTranscoderResult.packetDescriptions,
        sampleBufferOut: &sampleBufferOut
      )
      guard err1 == noErr, let sampleBuffer = sampleBufferOut else {
        XCTFail("Could not create CMSampleBuffer for AudioBufferList!")
        return
      }

      let err2 = CMSampleBufferSetDataBufferFromAudioBufferList(
        sampleBuffer,
        blockBufferAllocator: kCFAllocatorDefault,
        blockBufferMemoryAllocator: kCFAllocatorDefault,
        flags: 0,
        bufferList: &audioBufferList
      )
      guard err2 == noErr else {
        XCTFail("Could not load AudioBufferList to CMSampleBuffer!")
        return
      }

      try audioWriter.send(sampleBuffer: sampleBuffer)
    }

    try await audioWriter.close()

    _ = try audioWriter.writeIndexPlaylist()
  }
}
// swiftlint:enable function_body_length
