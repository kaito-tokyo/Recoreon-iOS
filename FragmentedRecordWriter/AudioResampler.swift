import CoreMedia
import Foundation

public enum AudioResamplerError: CustomNSError {
  case numChannelsNotSupported
  case appendingSampleRateNotSupported
}

public struct AudioResamplerFrame {
  public let numChannels: Int
  public let bytesPerFrame: Int
  public let numSamples: Int
  public let pts: CMTime
  public let data: UnsafeMutablePointer<Float32>
}

public class AudioResampler {
  public let duration: CMTime
  public let outputAudioStreamBasicDesc: AudioStreamBasicDescription

  private let outputSampleRate: Int

  private let underlyingBuffer: UnsafeMutablePointer<Float32>
  private let backOffTime: CMTime

  private var numSamples: Int = 0
  private var currentPTS: CMTime = .invalid

  private let bytesPerFrame = MemoryLayout<Float32>.size * 2
  private let bufferSize = 65536
  private let numOffsetSamples = 1024
  private let numBackOffSamples = 8

  public init(outputSampleRate: Int) throws {
    self.duration = CMTime(value: 1, timescale: CMTimeScale(outputSampleRate))

    self.outputAudioStreamBasicDesc = AudioStreamBasicDescription(
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

    self.outputSampleRate = outputSampleRate

    underlyingBuffer = .allocate(capacity: bufferSize)
    backOffTime = CMTime(
      value: CMTimeValue(numBackOffSamples), timescale: CMTimeScale(outputSampleRate))
  }

  private func shift() throws {
    let rawUnderlyingBuffer = UnsafeMutableRawPointer(underlyingBuffer)
    let tailRegionBuffer = rawUnderlyingBuffer.advanced(by: numSamples * bytesPerFrame)
    rawUnderlyingBuffer.copyMemory(
      from: tailRegionBuffer,
      byteCount: numOffsetSamples * bytesPerFrame
    )
  }

  public func append(
    stereoInt16Buffer: UnsafeMutablePointer<Int16>, numSamples: Int, inputSampleRate: Int,
    pts: CMTime
  ) throws {
    guard
      inputSampleRate == outputSampleRate || inputSampleRate * 2 == outputSampleRate
        || inputSampleRate * 6 == outputSampleRate
    else {
      throw AudioResamplerError.appendingSampleRateNotSupported
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)
    if inputSampleRate == outputSampleRate {
      copyStereoInt16(bodyBuffer, stereoInt16Buffer, numSamples)
      self.numSamples = numSamples
    } else if inputSampleRate * 2 == outputSampleRate {
      copyStereoInt16UpsamplingBy2(bodyBuffer, stereoInt16Buffer, numSamples)
      self.numSamples = numSamples * 2
    } else if inputSampleRate * 6 == outputSampleRate {
      copyStereoInt16UpsamplingBy6(bodyBuffer, stereoInt16Buffer, numSamples)
      self.numSamples = numSamples * 6
    }

    self.currentPTS = pts
  }

  public func append(
    monoInt16Buffer: UnsafeMutablePointer<Int16>, numSamples: Int, inputSampleRate: Int,
    pts: CMTime
  ) throws {
    guard
      inputSampleRate == outputSampleRate || inputSampleRate * 2 == outputSampleRate
        || inputSampleRate * 6 == outputSampleRate
    else {
      throw AudioResamplerError.appendingSampleRateNotSupported
    }

    try shift()

    print("mic", inputSampleRate, outputSampleRate)
    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)
    if inputSampleRate == outputSampleRate {
      copyMonoInt16(bodyBuffer, monoInt16Buffer, numSamples)
      self.numSamples = numSamples
    } else if inputSampleRate * 2 == outputSampleRate {
      copyMonoInt16UpsamplingBy2(bodyBuffer, monoInt16Buffer, numSamples)
      self.numSamples = numSamples * 2
    } else if inputSampleRate * 6 == outputSampleRate {
      copyMonoInt16UpsamplingBy6(bodyBuffer, monoInt16Buffer, numSamples)
      self.numSamples = numSamples * 6
    }

    self.currentPTS = pts
  }

  public func append(
    stereoInt16BufferWithSwap: UnsafeMutablePointer<Int16>,
    numSamples: Int,
    inputSampleRate: Int,
    pts: CMTime
  ) throws {
    guard
      inputSampleRate == outputSampleRate || inputSampleRate * 2 == outputSampleRate
        || inputSampleRate * 6 == outputSampleRate
    else {
      throw AudioResamplerError.appendingSampleRateNotSupported
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)
    if inputSampleRate == outputSampleRate {
      copyStereoInt16WithSwap(bodyBuffer, stereoInt16BufferWithSwap, numSamples)
      self.numSamples = numSamples
    } else if inputSampleRate * 2 == outputSampleRate {
      copyStereoInt16UpsamplingBy2WithSwap(bodyBuffer, stereoInt16BufferWithSwap, numSamples)
      self.numSamples = numSamples * 2
    } else if inputSampleRate * 6 == outputSampleRate {
      copyStereoInt16UpsamplingBy6WithSwap(bodyBuffer, stereoInt16BufferWithSwap, numSamples)
      self.numSamples = numSamples * 6
    }

    self.currentPTS = pts
  }

  public func append(
    monoInt16BufferWithSwap: UnsafeMutablePointer<Int16>, numSamples: Int, inputSampleRate: Int,
    pts: CMTime
  ) throws {
    guard
      inputSampleRate == outputSampleRate || inputSampleRate * 2 == outputSampleRate
        || inputSampleRate * 6 == outputSampleRate
    else {
      throw AudioResamplerError.appendingSampleRateNotSupported
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)
    if inputSampleRate == outputSampleRate {
      copyMonoInt16WithSwap(bodyBuffer, monoInt16BufferWithSwap, numSamples)
      self.numSamples = numSamples
    } else if inputSampleRate * 2 == outputSampleRate {
      copyMonoInt16UpsamplingBy2WithSwap(bodyBuffer, monoInt16BufferWithSwap, numSamples)
      self.numSamples = numSamples * 2
    } else if inputSampleRate * 6 == outputSampleRate {
      copyMonoInt16UpsamplingBy6WithSwap(bodyBuffer, monoInt16BufferWithSwap, numSamples)
      self.numSamples = numSamples * 6
    }

    self.currentPTS = pts
  }

  public func getCurrentFrame() -> AudioResamplerFrame {
    return AudioResamplerFrame(
      numChannels: 2,
      bytesPerFrame: 8,
      numSamples: numSamples,
      pts: CMTimeSubtract(currentPTS, backOffTime),
      data: underlyingBuffer.advanced(by: (numOffsetSamples - numBackOffSamples) * 2)
    )
  }
}
