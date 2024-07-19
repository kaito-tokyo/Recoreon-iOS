import CoreAudio
import CoreMedia
import Foundation

struct DummyAudioGeneratorFrame {
  let numSamples: Int
  let pts: CMTime
  let data: UnsafeMutablePointer<Int16>
  let audioBufferList: AudioBufferList
}

class DummyAudioGenerator {
  public let formatDesc: CMFormatDescription

  private let sampleRate: Int
  private let initialPTS: CMTime

  private var state: DummyAudioGeneratorState
  private var sampleIndex = 0

  private let numSamples = 1024
  private let numChannels = 2
  private let dataByteSize = 4096

  init(sampleRate: Int, initialPTS: CMTime) throws {
    formatDesc = try CMFormatDescription(
      audioStreamBasicDescription: AudioStreamBasicDescription(
        mSampleRate: Float64(sampleRate),
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0
      ))

    self.sampleRate = sampleRate
    self.initialPTS = initialPTS

    self.state = DummyAudioGeneratorState(
      data: .allocate(capacity: numSamples * numChannels * 10),
      numSamples: numSamples,
      numChannels: numChannels,
      t: 0,
      tincr: 2 * Double.pi * 330.0 / Double(sampleRate),
      tincr2: 2 * Double.pi * 330.0 / Double(sampleRate) / Double(sampleRate)
    )
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
          mDataByteSize: UInt32(dataByteSize),
          mData: state.data
        )
      )
    )
  }
}
