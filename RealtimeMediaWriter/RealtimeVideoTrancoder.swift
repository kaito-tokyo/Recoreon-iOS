import CoreVideo
import Foundation
import VideoToolbox

public enum RealtimeVideoTranscoderError: CustomNSError {
  case compressionSessionCreationFailure
  case frameEncodeError

  public var errorUserInfo: [String: Any] {
    switch self {
    case .compressionSessionCreationFailure:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not create VTCompressionSession!"
      ]
    case .frameEncodeError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not start to encode frame!"
      ]
    }
  }
}

public class RealtimeVideoTranscoder {
  private let compressionSession: VTCompressionSession

  public init(width: Int, height: Int) throws {
    let videoEncoderSpecification =
      [
        kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true as CFBoolean
      ] as CFDictionary

    let sourceImageBufferAttributes =
      [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as CFNumber]
      as CFDictionary

    var compressionSessionOut: VTCompressionSession?
    let err = VTCompressionSessionCreate(
      allocator: kCFAllocatorDefault,
      width: Int32(width),
      height: Int32(height),
      codecType: kCMVideoCodecType_H264,
      encoderSpecification: videoEncoderSpecification,
      imageBufferAttributes: sourceImageBufferAttributes,
      compressedDataAllocator: nil,
      outputCallback: nil,
      refcon: nil,
      compressionSessionOut: &compressionSessionOut
    )

    guard err == noErr, let compressionSession = compressionSessionOut else {
      print(err)
      throw RealtimeVideoTranscoderError.compressionSessionCreationFailure
    }

    self.compressionSession = compressionSession
  }

  public func sendImageBuffer(
    imageBuffer: CVImageBuffer,
    pts: CMTime,
    outputHandler: @escaping VTCompressionOutputHandler
  ) {
    let err = VTCompressionSessionEncodeFrame(
      compressionSession,
      imageBuffer: imageBuffer,
      presentationTimeStamp: pts,
      duration: .invalid,
      frameProperties: nil,
      infoFlagsOut: nil,
      outputHandler: outputHandler
    )

    guard err == noErr else { return }
  }

  public func close() {
    VTCompressionSessionCompleteFrames(compressionSession, untilPresentationTimeStamp: .invalid)
  }
}
