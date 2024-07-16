import CoreVideo
import Foundation
import VideoToolbox

enum RealtimeVideoTranscoderError: CustomNSError {
  case compressionSessionCreationFailure

  var errorUserInfo: [String: Any] {
    switch self {
    case .compressionSessionCreationFailure:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not create VTCompressionSession!"
      ]
    }
  }
}

class RealtimeVideoTranscoder {
  private let compressionSession: VTCompressionSession

  init(width: Int, height: Int) throws {
    let videoEncoderSpecification =
      [kVTVideoEncoderSpecification_EnableLowLatencyRateControl: true as CFBoolean] as CFDictionary

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
      throw RealtimeVideoTranscoderError.compressionSessionCreationFailure
    }

    self.compressionSession = compressionSession
  }

  func sendPixel(
    imageBuffer: CVImageBuffer, pts: CMTime, outputHandler: @escaping VTCompressionOutputHandler
  ) {
    let err = VTCompressionSessionEncodeFrame(
      compressionSession,
      imageBuffer: imageBuffer,
      presentationTimeStamp: pts,
      duration: .invalid,
      frameProperties: nil,
      infoFlagsOut: nil,
      outputHandler: outputHandler)
    guard err == noErr else {
      print("aaa!")
      return
    }
  }
}
