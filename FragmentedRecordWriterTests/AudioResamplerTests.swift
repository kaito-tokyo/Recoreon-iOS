import AVFoundation
import CoreAudio
import Foundation
import FragmentedRecordWriter
import XCTest

private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

// swiftlint:disable function_body_length
final class AudioResamplerTests: XCTestCase {
  let className = "AudioResamplerTests"

  func getOutputDirectoryURL(name: String) throws -> URL {
    let outputDirectoryURL = documentsURL.appending(path: name)

    try? FileManager.default.removeItem(at: outputDirectoryURL)
    try FileManager.default.createDirectory(
      at: outputDirectoryURL,
      withIntermediateDirectories: true
    )

    return outputDirectoryURL
  }

  func testCopyInt16() async throws {
    for numChannels in [1, 2] {
      for isSwapped in [false, true] {
        try await run(
          name: "\(className)_testCopyInt16_\(numChannels)_\(isSwapped)",
          inputSampleRate: 48_000,
          outputSampleRate: 48_000,
          numChannels: numChannels,
          bytesPerSample: 2,
          isSwapped: isSwapped
        )
      }
    }
  }

  func testUpsamplingBy2() async throws {
    try await run(
      name: "\(className)_\(#function)",
      inputSampleRate: 24_000,
      outputSampleRate: 48_000,
      numChannels: 2,
      bytesPerSample: 2,
      isSwapped: false
    )
  }

  func testUpsamplingBy6() async throws {
    try await run(
      name: "\(className)_\(#function)",
      inputSampleRate: 8_000,
      outputSampleRate: 48_000,
      numChannels: 2,
      bytesPerSample: 2,
      isSwapped: false
    )
  }

  func testUpsamplingFrom44100To48000() async throws {
    try await run(
      name: "\(className)_\(#function)",
      inputSampleRate: 44_100,
      outputSampleRate: 48_000,
      numChannels: 2,
      bytesPerSample: 2,
      isSwapped: false
    )
  }

  private func run(
    name: String,
    inputSampleRate: Int,
    outputSampleRate: Int,
    numChannels: Int,
    bytesPerSample: Int,
    isSwapped: Bool
  ) async throws {
    let outputDirectoryURL = try getOutputDirectoryURL(name: name)
    print("Output directory is \(outputDirectoryURL.path())")

    let dummyAppAudioGenerator = try DummyAudioGenerator(
      sampleRate: inputSampleRate,
      numChannels: numChannels,
      bytesPerSample: bytesPerSample,
      isSwapped: isSwapped,
      initialPTS: .zero
    )

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

    for _ in 0..<inputSampleRate * 10 / 1024 {
      let dummyAudioFrame = dummyAppAudioGenerator.generateNextAudioFrame()

      if bytesPerSample == 1 {
      } else if bytesPerSample == 2 {
        if numChannels == 1 {
          if isSwapped {
            try audioResampler.append(
              monoInt16BufferWithSwap: dummyAudioFrame.data.assumingMemoryBound(to: Int16.self),
              numInputSamples: dummyAudioFrame.numSamples,
              inputSampleRate: inputSampleRate,
              pts: dummyAudioFrame.pts
            )
          } else {
            try audioResampler.append(
              monoInt16Buffer: dummyAudioFrame.data.assumingMemoryBound(to: Int16.self),
              numInputSamples: dummyAudioFrame.numSamples,
              inputSampleRate: inputSampleRate,
              pts: dummyAudioFrame.pts
            )
          }
        } else if numChannels == 2 {
          if isSwapped {
            try audioResampler.append(
              stereoInt16BufferWithSwap: dummyAudioFrame.data.assumingMemoryBound(to: Int16.self),
              numInputSamples: dummyAudioFrame.numSamples,
              inputSampleRate: inputSampleRate,
              pts: dummyAudioFrame.pts
            )
          } else {
            try audioResampler.append(
              stereoInt16Buffer: dummyAudioFrame.data.assumingMemoryBound(to: Int16.self),
              numInputSamples: dummyAudioFrame.numSamples,
              inputSampleRate: inputSampleRate,
              pts: dummyAudioFrame.pts
            )
          }
        }
      }
      let audioResamplerFrame = audioResampler.getCurrentFrame()

      let numInputSamples = audioResamplerFrame.numSamples
      let audioTranscoderFrame = try audioTranscoder.send(
        inputBuffer: audioResamplerFrame.data,
        numInputSamples: numInputSamples
      )

      let packetDescs = Array(
        UnsafeBufferPointer(
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
  }
}
// swiftlint:enable function_body_length
