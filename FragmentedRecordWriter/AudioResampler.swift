import CoreMedia
import Foundation

public enum AudioResamplerError: CustomNSError {
  case numChannelsNotSupported
  case appendingSampleRateNotSupported(inputSampleRate: Int, outputSampleRate: Int)
}

public struct AudioResamplerFrame {
  public let numChannels: Int
  public let bytesPerFrame: Int
  public let numSamples: Int
  public let pts: CMTime
  public let data: UnsafeMutablePointer<Float32>
}

private enum AudioResamplerMode {
  case copy
  case upsampleBy2
  case upsampleBy6
  case upsampleFrom44100To48000
  case notSupported

  static func calculateMode(
    inputSampleRate: Int,
    outputSampleRate: Int
  ) -> AudioResamplerMode {
    if inputSampleRate == outputSampleRate {
      return .copy
    } else if inputSampleRate * 2 == outputSampleRate {
      return .upsampleBy2
    } else if inputSampleRate * 6 == outputSampleRate {
      return .upsampleBy6
    } else if inputSampleRate == 44100 && outputSampleRate == 48000 {
      return .upsampleFrom44100To48000
    } else {
      return .notSupported
    }
  }
}

public class AudioResampler {
  public let duration: CMTime
  public let outputAudioStreamBasicDesc: AudioStreamBasicDescription

  private let outputSampleRate: Int

  private let underlyingBuffer: UnsafeMutablePointer<Float32>
  private let backOffTime: CMTime

  private var numSamples: Int = 0
  private var currentPTS: CMTime = .invalid
  private var currentOutputPTS: CMTime = .invalid

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
    stereoInt16Buffer: UnsafeMutablePointer<Int16>, numInputSamples: Int, inputSampleRate: Int,
    pts: CMTime
  ) throws {
    let mode = AudioResamplerMode.calculateMode(
      inputSampleRate: inputSampleRate,
      outputSampleRate: outputSampleRate
    )

    guard mode != .notSupported else {
      throw AudioResamplerError.appendingSampleRateNotSupported(
        inputSampleRate: inputSampleRate,
        outputSampleRate: outputSampleRate
      )
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)

    switch mode {
    case .copy:
      copyStereoInt16(bodyBuffer, stereoInt16Buffer, numInputSamples)
      self.numSamples = numInputSamples
    case .upsampleBy2:
      copyStereoInt16UpsamplingBy2(bodyBuffer, stereoInt16Buffer, numInputSamples)
      self.numSamples = numInputSamples * 2
    case .upsampleBy6:
      copyStereoInt16UpsamplingBy6(bodyBuffer, stereoInt16Buffer, numInputSamples)
      self.numSamples = numInputSamples * 6
    case .upsampleFrom44100To48000:
      let numOutputSamples = numInputSamples * outputSampleRate / inputSampleRate
      for outputIndex in 0..<numOutputSamples {
        let inputSamplingPoint =
          Float(outputIndex) * Float(inputSampleRate) / Float(outputSampleRate)
        let inputIndex = Int(inputSamplingPoint)
        let fraction = inputSamplingPoint - Float(inputIndex)
        bodyBuffer[outputIndex * 2 + 0] =
          Float(stereoInt16Buffer[inputIndex * 2 + 0]) / 32768.0 + fraction
          * (Float(stereoInt16Buffer[inputIndex * 2 + 2])
            - Float(stereoInt16Buffer[inputIndex * 2 + 0])) / 32768.0
        bodyBuffer[outputIndex * 2 + 1] =
          Float(stereoInt16Buffer[inputIndex * 2 + 1]) / 32768.0 + fraction
          * (Float(stereoInt16Buffer[inputIndex * 2 + 3])
            - Float(stereoInt16Buffer[inputIndex * 2 + 1])) / 32768.0
      }
      self.numSamples = numOutputSamples
    case .notSupported:
      break
    }

    self.currentPTS = pts
  }

  public func append(
    monoInt16Buffer: UnsafeMutablePointer<Int16>, numInputSamples: Int, inputSampleRate: Int,
    pts: CMTime
  ) throws {
    let mode = AudioResamplerMode.calculateMode(
      inputSampleRate: inputSampleRate,
      outputSampleRate: outputSampleRate
    )

    guard mode != .notSupported else {
      throw AudioResamplerError.appendingSampleRateNotSupported(
        inputSampleRate: inputSampleRate,
        outputSampleRate: outputSampleRate
      )
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)

    switch mode {
    case .copy:
      copyMonoInt16(bodyBuffer, monoInt16Buffer, numInputSamples)
      self.numSamples = numInputSamples
    case .upsampleBy2:
      copyMonoInt16UpsamplingBy2(bodyBuffer, monoInt16Buffer, numInputSamples)
      self.numSamples = numInputSamples * 2
    case .upsampleBy6:
      copyMonoInt16UpsamplingBy6(bodyBuffer, monoInt16Buffer, numInputSamples)
      self.numSamples = numInputSamples * 6
    case .upsampleFrom44100To48000:
      let numOutputSamples = numInputSamples * outputSampleRate / inputSampleRate
      for outputIndex in 0..<numOutputSamples {
        let inputSamplingPoint =
          Float(outputIndex) * Float(inputSampleRate) / Float(outputSampleRate)
        let inputIndex = Int(inputSamplingPoint)
        let fraction = inputSamplingPoint - Float(inputIndex)
        let value =
          Float(monoInt16Buffer[inputIndex]) / 32768.0 + fraction
          * (Float(monoInt16Buffer[inputIndex + 1]) - Float(monoInt16Buffer[inputIndex])) / 32768.0
        bodyBuffer[outputIndex * 2 + 0] = value
        bodyBuffer[outputIndex * 2 + 1] = value
      }
      self.numSamples = numOutputSamples
    case .notSupported:
      break
    }

    self.currentPTS = pts
  }

  public func append(
    stereoInt16BufferWithSwap: UnsafeMutablePointer<Int16>,
    numInputSamples: Int,
    inputSampleRate: Int,
    pts: CMTime
  ) throws {
    let mode = AudioResamplerMode.calculateMode(
      inputSampleRate: inputSampleRate,
      outputSampleRate: outputSampleRate
    )

    guard mode != .notSupported else {
      throw AudioResamplerError.appendingSampleRateNotSupported(
        inputSampleRate: inputSampleRate,
        outputSampleRate: outputSampleRate
      )
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)

    switch mode {
    case .copy:
      copyStereoInt16WithSwap(bodyBuffer, stereoInt16BufferWithSwap, numInputSamples)
      self.numSamples = numInputSamples
    case .upsampleBy2:
      copyStereoInt16UpsamplingBy2WithSwap(bodyBuffer, stereoInt16BufferWithSwap, numInputSamples)
      self.numSamples = numInputSamples * 2
    case .upsampleBy6:
      copyStereoInt16UpsamplingBy6WithSwap(bodyBuffer, stereoInt16BufferWithSwap, numInputSamples)
      self.numSamples = numInputSamples * 6
    case .upsampleFrom44100To48000:
      let numOutputSamples = numInputSamples * outputSampleRate / inputSampleRate
      self.numSamples = numOutputSamples
    case .notSupported:
      break
    }

    self.currentPTS = pts
  }

  public func append(
    monoInt16BufferWithSwap: UnsafeMutablePointer<Int16>, numInputSamples: Int,
    inputSampleRate: Int,
    pts: CMTime
  ) throws {
    let mode = AudioResamplerMode.calculateMode(
      inputSampleRate: inputSampleRate,
      outputSampleRate: outputSampleRate
    )

    guard mode != .notSupported else {
      throw AudioResamplerError.appendingSampleRateNotSupported(
        inputSampleRate: inputSampleRate,
        outputSampleRate: outputSampleRate
      )
    }

    try shift()

    let bodyBuffer = underlyingBuffer.advanced(by: numOffsetSamples * 2)

    switch mode {
    case .copy:
      copyMonoInt16WithSwap(bodyBuffer, monoInt16BufferWithSwap, numInputSamples)
      self.numSamples = numInputSamples
    case .upsampleBy2:
      copyMonoInt16UpsamplingBy2WithSwap(bodyBuffer, monoInt16BufferWithSwap, numInputSamples)
      self.numSamples = numInputSamples * 2
    case .upsampleBy6:
      copyMonoInt16UpsamplingBy6WithSwap(bodyBuffer, monoInt16BufferWithSwap, numInputSamples)
      self.numSamples = numInputSamples * 6
    case .upsampleFrom44100To48000:
      let numOutputSamples = numInputSamples * outputSampleRate / inputSampleRate
      self.numSamples = numOutputSamples
    case .notSupported:
      break
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
