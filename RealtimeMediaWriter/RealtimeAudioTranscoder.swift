import Foundation
import AudioToolbox
import CoreMedia

public enum RealtimeAudioTranscoderError: CustomNSError {
  case audioConverterCreationFailure
  case audioConverterConversionFailure
}

private struct InputContext {
  let inputBuffer: UnsafeMutablePointer<Float>
}

private let numChannels = 2
private let numInputSamples = 4096

public let kRealTimeAudioTranscoderInputASBD = AudioStreamBasicDescription(
  mSampleRate: 48_000,
  mFormatID: kAudioFormatLinearPCM,
  mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
  mBytesPerPacket: 8,
  mFramesPerPacket: 1,
  mBytesPerFrame: 8,
  mChannelsPerFrame: 2,
  mBitsPerChannel: 32,
  mReserved: 0
)

public let kRealTimeAudioTranscoderOutputASBD = AudioStreamBasicDescription(
  mSampleRate: 48_000,
  mFormatID: kAudioFormatMPEG4AAC,
  mFormatFlags: kAudioFormatFlagsAreAllClear,
  mBytesPerPacket: 0,
  mFramesPerPacket: 1024,
  mBytesPerFrame: 0,
  mChannelsPerFrame: 2,
  mBitsPerChannel: 0,
  mReserved: 0
)

private func inputDataProc(
  inAudioConverter: AudioConverterRef,
  ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
  ioData: UnsafeMutablePointer<AudioBufferList>,
  outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
  inUserData: UnsafeMutableRawPointer?
) -> OSStatus {
  let inputContext = inUserData!.assumingMemoryBound(to: InputContext.self).pointee

  ioData.pointee.mNumberBuffers = 1
  ioData.pointee.mBuffers.mNumberChannels = UInt32(numChannels)
  ioData.pointee.mBuffers.mDataByteSize = UInt32(numInputSamples) * kRealTimeAudioTranscoderInputASBD.mBytesPerPacket
  ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(inputContext.inputBuffer)

  ioNumberDataPackets.pointee = UInt32(numInputSamples)

  return noErr
//  guard let context = inUserData?.assumingMemoryBound(to: InputContext.self) else {
//    return noErr
//  }
//
//  let byteCount = numInputSamples * numChannels * MemoryLayout<Float>.size
//
//  ioData.pointee.mNumberBuffers = 1
//  ioData.pointee.mBuffers.mNumberChannels = UInt32(numChannels)
//  let inputAudioBufferList = AudioBufferList(
//    mNumberBuffers: 1,
//    mBuffers: AudioBuffer(
//      mNumberChannels: UInt32(numChannels),
//      mDataByteSize: UInt32(byteCount),
//      mData: .allocate(byteCount: byteCount, alignment: MemoryLayout<Float>.size)
//    )
//  )
//  return noErr
}

public struct RealtimeAudioTranscoder {
  private let audioConverter: AudioConverterRef

  private let maxOutputPacketSize: Int
  private let packetBuffer: UnsafeMutableRawPointer
  private let inputBuffer: UnsafeMutablePointer<Float>

  private let numChannels = 2
  private let packetsPerLoop = 4

  public init() throws {
    var err: OSStatus

    var inputAudioStreamBasicDescription = kRealTimeAudioTranscoderInputASBD
    var outputAudioStreamBasicDescription = kRealTimeAudioTranscoderOutputASBD
    var audioConverterOut: AudioConverterRef?
    err = AudioConverterNew(&inputAudioStreamBasicDescription, &outputAudioStreamBasicDescription, &audioConverterOut)
    guard err == noErr, let audioConverter = audioConverterOut else {
      throw RealtimeAudioTranscoderError.audioConverterCreationFailure
    }
    self.audioConverter = audioConverter

    var maxOutputPacketSize: UInt32 = 0
    var maxOutputPacketSizeDataSize = UInt32(MemoryLayout<UInt32>.size)
    err = AudioConverterGetProperty(audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &maxOutputPacketSizeDataSize, &maxOutputPacketSize)
    self.maxOutputPacketSize = Int(maxOutputPacketSize)

    packetBuffer = .allocate(byteCount: packetsPerLoop * self.maxOutputPacketSize, alignment: 8)
    inputBuffer = .allocate(capacity: numInputSamples * Int(inputAudioStreamBasicDescription.mBytesPerPacket))
  }

  public func send(abl: AudioBufferList, sampleRate: Int, pts: CMTime) throws -> [AudioBufferList] {
    var inputContext = InputContext(inputBuffer: inputBuffer)
    var numPackets = UInt32(packetsPerLoop)

    var outputABL = AudioBufferList(
      mNumberBuffers: 1,
      mBuffers: AudioBuffer(
        mNumberChannels: UInt32(numChannels),
        mDataByteSize: UInt32(packetsPerLoop * self.maxOutputPacketSize),
        mData: packetBuffer
      )
    )

    let err = AudioConverterFillComplexBuffer(
      audioConverter,
      inputDataProc,
      &inputContext,
      &numPackets,
      &outputABL,
      nil
    )
    guard err == noErr else {
      throw RealtimeAudioTranscoderError.audioConverterConversionFailure
    }

    return [outputABL]
  }
}
