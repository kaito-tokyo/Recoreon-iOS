import AudioToolbox
import CoreAudio
import CoreMedia
import Foundation

let kRealtimeAudioTranscoder_NoInputContextError: OSStatus = 9999
let kRealtimeAudioTranscoder_RanOutOfInputSamples: OSStatus = 9998

public enum RealtimeAudioTranscoderError: CustomNSError {
  case inputAudioFormatNotSupported(formatID: AudioFormatID)
  case outputAudioFormatNotSupported(formatID: AudioFormatID)
  case audioConverterCreationFailure(err: OSStatus)
  case audioConverterConversionFailure(err: OSStatus)
  case audioConverterNoPropertyOfMaximumOutputPacketSize(err: OSStatus)

  public var errorUserInfo: [String: Any] {
    switch self {
    case .inputAudioFormatNotSupported(let formatID):
      return [
        NSLocalizedFailureReasonErrorKey: "Input format \(formatID) is not supported!"
      ]
    case .outputAudioFormatNotSupported(let formatID):
      return [
        NSLocalizedFailureReasonErrorKey: "Output format \(formatID) is not supported!"
      ]
    case .audioConverterCreationFailure(let err):
      return [
        NSLocalizedFailureReasonErrorKey: "Could not create AudioConverter! Error code is \(err)"
      ]
    case .audioConverterConversionFailure(let err):
      return [
        NSLocalizedFailureReasonErrorKey: "Could not open the video codec! Error code is \(err)"
      ]
    case .audioConverterNoPropertyOfMaximumOutputPacketSize(let err):
      return [
        NSLocalizedFailureReasonErrorKey:
          "Could not get MaximumOutputPacketSize! Error code is \(err)"
      ]
    }
  }
}

private struct InputContext {
  let numChannels: UInt32
  let numInputSamples: UInt32
  let numBytesPerFrame: UInt32
  let inputBuffer: UnsafeMutableRawPointer
  var done: Bool = false
}

private func inputDataProc(
  inAudioConverter: AudioConverterRef,
  ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
  ioData: UnsafeMutablePointer<AudioBufferList>,
  outDataPacketDescription: UnsafeMutablePointer<
    UnsafeMutablePointer<AudioStreamPacketDescription>?
  >?,
  inUserData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let inputContext = inUserData?.assumingMemoryBound(to: InputContext.self) else {
    ioNumberDataPackets.pointee = 0
    return kRealtimeAudioTranscoder_NoInputContextError
  }

  guard !inputContext.pointee.done else {
    ioNumberDataPackets.pointee = 0
    return kRealtimeAudioTranscoder_RanOutOfInputSamples
  }

  ioData.pointee.mNumberBuffers = 1
  ioData.pointee.mBuffers.mNumberChannels = inputContext.pointee.numChannels
  ioData.pointee.mBuffers.mDataByteSize =
    inputContext.pointee.numInputSamples * inputContext.pointee.numBytesPerFrame
  ioData.pointee.mBuffers.mData = inputContext.pointee.inputBuffer

  ioNumberDataPackets.pointee = UInt32(inputContext.pointee.numInputSamples)

  inputContext.pointee.done = true

  return noErr
}

public struct RealtimeAudioTranscoderResult {
  public let numPackets: Int
  public let audioBufferList: AudioBufferList
  public let packetDescriptions: UnsafePointer<AudioStreamPacketDescription>
}

public struct RealtimeAudioTranscoder {
  private let inputAudioStreamBasicDescription: AudioStreamBasicDescription
  private let outputAudioStreamBasicDescription: AudioStreamBasicDescription

  private let audioConverter: AudioConverterRef

  private let maxOutputPacketSize: Int
  private let packetBuffer: UnsafeMutableRawBufferPointer
  private let packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>

  private let packetsPerLoop = 10000

  public init(
    inputAudioStreamBasicDescription: AudioStreamBasicDescription,
    outputAudioStreamBasicDescription: AudioStreamBasicDescription
  ) throws {
    guard inputAudioStreamBasicDescription.mFormatID == kAudioFormatLinearPCM else {
      throw RealtimeAudioTranscoderError.inputAudioFormatNotSupported(
        formatID: inputAudioStreamBasicDescription.mFormatID
      )
    }

    guard outputAudioStreamBasicDescription.mFormatID == kAudioFormatMPEG4AAC else {
      throw RealtimeAudioTranscoderError.outputAudioFormatNotSupported(
        formatID: outputAudioStreamBasicDescription.mFormatID
      )
    }

    self.inputAudioStreamBasicDescription = inputAudioStreamBasicDescription
    self.outputAudioStreamBasicDescription = outputAudioStreamBasicDescription

    var inputAudioStreamBasicDescription = inputAudioStreamBasicDescription
    var outputAudioStreamBasicDescription = outputAudioStreamBasicDescription

    var audioConverterOut: AudioConverterRef?
    let err1 = AudioConverterNew(
      &inputAudioStreamBasicDescription,
      &outputAudioStreamBasicDescription,
      &audioConverterOut
    )
    guard err1 == noErr, let audioConverter = audioConverterOut else {
      throw RealtimeAudioTranscoderError.audioConverterCreationFailure(err: err1)
    }
    self.audioConverter = audioConverter

    var maxOutputPacketSize: UInt32 = 0
    var maxOutputPacketSizeDataSize = UInt32(MemoryLayout<UInt32>.size)
    let err2 = AudioConverterGetProperty(
      audioConverter,
      kAudioConverterPropertyMaximumOutputPacketSize,
      &maxOutputPacketSizeDataSize,
      &maxOutputPacketSize
    )
    guard err2 == noErr else {
      throw RealtimeAudioTranscoderError.audioConverterNoPropertyOfMaximumOutputPacketSize(
        err: err2)
    }
    self.maxOutputPacketSize = Int(maxOutputPacketSize)

    packetBuffer = .allocate(
      byteCount: packetsPerLoop * self.maxOutputPacketSize,
      alignment: 1
    )

    packetDescriptions = .allocate(capacity: packetsPerLoop)
  }

  public func send(
    inputBuffer: UnsafeMutableRawPointer,
    numInputSamples: Int
  ) throws -> RealtimeAudioTranscoderResult {
    var inputContext = InputContext(
      numChannels: inputAudioStreamBasicDescription.mChannelsPerFrame,
      numInputSamples: UInt32(numInputSamples),
      numBytesPerFrame: inputAudioStreamBasicDescription.mBytesPerFrame,
      inputBuffer: inputBuffer,
      done: false
    )
    var numPackets = UInt32(packetsPerLoop)
    var outputAudioBufferList = AudioBufferList(
      mNumberBuffers: 1,
      mBuffers: AudioBuffer(
        mNumberChannels: outputAudioStreamBasicDescription.mChannelsPerFrame,
        mDataByteSize: UInt32(packetBuffer.count),
        mData: packetBuffer.baseAddress
      )
    )

    let err = AudioConverterFillComplexBuffer(
      audioConverter,
      inputDataProc(
        inAudioConverter:ioNumberDataPackets:ioData:outDataPacketDescription:inUserData:),
      &inputContext,
      &numPackets,
      &outputAudioBufferList,
      packetDescriptions
    )
    guard err == noErr || err == 9998 else {
      throw RealtimeAudioTranscoderError.audioConverterConversionFailure(err: err)
    }

    return RealtimeAudioTranscoderResult(
      numPackets: Int(numPackets),
      audioBufferList: outputAudioBufferList,
      packetDescriptions: packetDescriptions
    )
  }
}
