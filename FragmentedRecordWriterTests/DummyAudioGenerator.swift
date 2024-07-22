import CoreAudio
import CoreMedia
import Foundation

enum DummyAudioGeneratorError: Error {
  case initializingParameterNotSupported(numChannels: Int, bytesPerSample: Int)
}

struct DummyAudioGeneratorFrame {
  let numSamples: Int
  let pts: CMTime
  let data: UnsafeMutableRawPointer
  let audioBufferList: AudioBufferList
}

class DummyAudioGenerator {
  public let formatDesc: CMFormatDescription

  private let sampleRate: Int
  private let bytesPerSample: Int
  private let initialPTS: CMTime

  private var state: DummyAudioGeneratorState
  private var sampleIndex = 0

  private let numSamples = 1024
  private let numChannels = 2
  private let dataByteSize = 4096

  init(
    sampleRate: Int,
    numChannels: Int,
    bytesPerSample: Int,
    isSwapped: Bool,
    initialPTS: CMTime
  ) throws {
    guard [1, 2].contains(numChannels) else {
      throw DummyAudioGeneratorError.initializingParameterNotSupported(
        numChannels: numChannels,
        bytesPerSample: bytesPerSample
      )
    }

    let formatFlags: AudioFormatFlags
    if bytesPerSample == 1 {
      formatFlags = kAudioFormatFlagIsPacked
    } else if bytesPerSample == 2 {
      formatFlags = kAudioFormatFlagIsSignedInteger | (isSwapped ? kAudioFormatFlagIsBigEndian : 0) | kAudioFormatFlagIsPacked
    } else {
      throw DummyAudioGeneratorError.initializingParameterNotSupported(
        numChannels: numChannels,
        bytesPerSample: bytesPerSample
      )
    }

    let bytesPerFrame = bytesPerSample * numChannels

    formatDesc = try CMFormatDescription(
      audioStreamBasicDescription: AudioStreamBasicDescription(
        mSampleRate: Float64(sampleRate),
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: formatFlags,
        mBytesPerPacket: UInt32(bytesPerFrame),
        mFramesPerPacket: 1,
        mBytesPerFrame: UInt32(bytesPerFrame),
        mChannelsPerFrame: UInt32(numChannels),
        mBitsPerChannel: UInt32(bytesPerSample * 8),
        mReserved: 0
      )
    )

    self.sampleRate = sampleRate
    self.bytesPerSample = bytesPerSample
    self.initialPTS = initialPTS

    let dataSize = numSamples * numChannels * bytesPerSample * 16

    self.state = DummyAudioGeneratorState(
      data: .allocate(byteCount: dataSize, alignment: 8),
      numSamples: numSamples,
      numChannels: numChannels,
      bytesPerSample: bytesPerSample,
      isSwapped: isSwapped,
      t: 0,
      tincr: 2 * Double.pi * 330.0 / Double(sampleRate),
      tincr2: 2 * Double.pi * 330.0 / Double(sampleRate) / Double(sampleRate)
    )

    state.data.initializeMemory(as: UInt8.self, repeating: 0, count: dataSize)
  }

  func generateNextAudioFrame() -> DummyAudioGeneratorFrame {
    let elapsedTime = CMTime(value: CMTimeValue(sampleIndex), timescale: CMTimeScale(sampleRate))
    let pts = CMTimeAdd(initialPTS, elapsedTime)

    fillAudio(&state)

    sampleIndex += numSamples

    return DummyAudioGeneratorFrame(
      numSamples: numSamples,
      pts: pts,
      data: state.data,
      audioBufferList: AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
          mNumberChannels: UInt32(numChannels),
          mDataByteSize: UInt32(numSamples * numChannels * bytesPerSample),
          mData: state.data
        )
      )
    )
  }
}
