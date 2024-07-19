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
  private let outputSampleRate: Int

  private let underlyingBuffer: UnsafeMutablePointer<Float32>
  private let startIndexOfSampleRegion: Int
  private let headRegionByteCount: Int

  private var numSamples: Int = 0
  private var currentPTS: CMTime = .invalid

  private let bytesPerFrame = MemoryLayout<Float32>.size * 2
  private let bufferSize = 65536
  private let numOffsetSamples = 1024

  public init(outputSampleRate: Int) throws {
    self.outputSampleRate = outputSampleRate

    underlyingBuffer = .allocate(capacity: bufferSize)
    headRegionByteCount = numOffsetSamples * bytesPerFrame
    startIndexOfSampleRegion = numOffsetSamples * bytesPerFrame
  }

  private func shift() throws {
    let rawUnderlyingBuffer = UnsafeMutableRawPointer(underlyingBuffer)
    let startIndexOfTailRegion = numSamples * bytesPerFrame
    let tailRegionBuffer = rawUnderlyingBuffer.advanced(by: startIndexOfTailRegion)
    rawUnderlyingBuffer.copyMemory(from: tailRegionBuffer, byteCount: headRegionByteCount)
  }

  public func append(
    stereoInt16Buffer: UnsafeMutablePointer<Int16>, numSamples: Int, inputSampleRate: Int, pts: CMTime
  ) throws {
    guard inputSampleRate == outputSampleRate || inputSampleRate * 2 == outputSampleRate || inputSampleRate * 6 == outputSampleRate  else {
      throw AudioResamplerError.appendingSampleRateNotSupported
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)
    if inputSampleRate == outputSampleRate {
      copyStereoInt16(bodyBuffer, stereoInt16Buffer, numSamples);
      self.numSamples = numSamples
      self.currentPTS = pts
    } else if inputSampleRate * 2 == outputSampleRate {
      copyStereoInt16UpsamplingBy2(bodyBuffer, stereoInt16Buffer, numSamples);
      self.numSamples = numSamples * 2
      self.currentPTS = pts
    } else if inputSampleRate * 6 == outputSampleRate {
      copyStereoInt16UpsamplingBy6(bodyBuffer, stereoInt16Buffer, numSamples);
      self.numSamples = numSamples * 6
      self.currentPTS = pts
    }
  }

  public func getCurrentFrame() -> AudioResamplerFrame {
    return AudioResamplerFrame(
      numChannels: 2,
      bytesPerFrame: 8,
      numSamples: numSamples,
      pts: currentPTS,
      data: underlyingBuffer.advanced(by: numOffsetSamples * 2)
    )
  }
}
