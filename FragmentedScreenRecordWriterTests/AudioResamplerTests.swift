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

    let audioResampler = try AudioResampler(outputSampleRate: outputSampleRate)

    let audioTranscoder = try RealtimeAudioTranscoder(
      inputAudioStreamBasicDesc: audioResampler.outputAudioStreamBasicDesc,
      outputSampleRate: outputSampleRate
    )

    let audioWriter = try FragmentedAudioWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: name,
      sampleRate: outputSampleRate,
      sourceFormatHint: audioTranscoder.outputFormatDesc
    )

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
      let audioTranscoderFrame = try audioTranscoder.send(
        inputBuffer: audioResamplerFrame.data,
        numInputSamples: numInputSamples
      )

      let packetDescs = Array(UnsafeBufferPointer(
        start: audioTranscoderFrame.packetDescs,
        count: audioTranscoderFrame.numPackets
      ))

      let buffer = UnsafeMutableRawBufferPointer(
        start: audioTranscoderFrame.audioBufferList.mBuffers.mData,
        count: Int(audioTranscoderFrame.audioBufferList.mBuffers.mDataByteSize)
      )
      let blockBuffer = try CMBlockBuffer(buffer: buffer, allocator: kCFAllocatorNull)
      let sampleBuffer = try CMSampleBuffer(
        dataBuffer: blockBuffer,
        formatDescription: audioTranscoder.outputFormatDesc,
        numSamples: audioTranscoderFrame.numPackets,
        presentationTimeStamp: dummyAudioFrame.pts,
        packetDescriptions: packetDescs
      )

      try audioWriter.send(sampleBuffer: sampleBuffer)

      try await Task.sleep(nanoseconds: 1_000_000_000 / 48_000)
    }

    try await audioWriter.close()

    _ = try audioWriter.writeIndexPlaylist()
  }
}
// swiftlint:enable function_body_length
