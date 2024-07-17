import Foundation
import AudioToolbox

public class RealtimeAudioTranscoder {

  public init() {
    let inputASBD = AudioStreamBasicDescription(
      mSampleRate: 96_000,
      mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
      mBytesPerPacket: 8,
      mFramesPerPacket: 1,
      mBytesPerFrame: 2,
      mChannelsPerFrame: 8,
      mBitsPerChannel: 32,
      mReserved: 0
    )

    let outputASBD = AudioStreamBasicDescription(
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
    AudioConverterNew(<#T##inSourceFormat: UnsafePointer<AudioStreamBasicDescription>##UnsafePointer<AudioStreamBasicDescription>#>, <#T##inDestinationFormat: UnsafePointer<AudioStreamBasicDescription>##UnsafePointer<AudioStreamBasicDescription>#>, <#T##outAudioConverter: UnsafeMutablePointer<AudioConverterRef?>##UnsafeMutablePointer<AudioConverterRef?>#>)
  }
}
