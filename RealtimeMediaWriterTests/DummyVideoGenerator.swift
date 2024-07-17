import CoreMedia
import CoreVideo
import Foundation

enum DummyVideoGeneratorError: Error {
  case pixelBufferCreationFailure
}

struct VideoFrame {
  let pixelBuffer: CVPixelBuffer
  let pts: CMTime
}

class DummyVideoGenerator {
  private let width: Int
  private let height: Int
  private let bytesPerRow: Int
  private let frameRate: Int
  private let initialPTS: CMTime

  private var frameIndex: Int = 0

  private let lumaData: UnsafeMutablePointer<UInt8>
  private let chromaData: UnsafeMutablePointer<UInt8>

  init(width: Int, height: Int, bytesPerRow: Int, frameRate: Int, initialPTS: CMTime) {
    self.width = width
    self.height = height
    self.bytesPerRow = bytesPerRow
    self.frameRate = frameRate
    self.initialPTS = initialPTS
    lumaData = .allocate(capacity: bytesPerRow * height)
    chromaData = .allocate(capacity: bytesPerRow * height / 2)
  }

  private func fillLumaPlane(frameIndex: Int) {
    var y: Int = 0
    var x: Int = 0
    while y < height {
      while x < width {
        lumaData[y * bytesPerRow + x] = UInt8((x + y + frameIndex * 3) & 0xFF)
        x += 1
      }
      y += 1
    }
  }

  private func fillChromaPlane(frameIndex: Int) {
    var y: Int = 0
    var x: Int = 0
    while y < height / 2 {
      while x < width {
        chromaData[y * bytesPerRow + x] = UInt8((128 + y + frameIndex * 2) & 0xFF)
        chromaData[y * bytesPerRow + x + 1] = UInt8((64 + x + frameIndex * 5) & 0xFF)
        x += 1
      }
      y += 1
    }
  }

  private func createPixelBuffer() throws -> CVPixelBuffer {
    var planeBaseAddresses = [
      Optional(UnsafeMutableRawPointer(lumaData)),
      Optional(UnsafeMutableRawPointer(chromaData)),
    ]
    var planeWIdth = [width, width]
    var planeHeight = [height, height]
    var planeBytesPerRow = [bytesPerRow, bytesPerRow]
    var pixelBufferOut: CVPixelBuffer?
    let err = CVPixelBufferCreateWithPlanarBytes(
      kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, 0, 2,
      &planeBaseAddresses, &planeWIdth, &planeHeight, &planeBytesPerRow, nil, nil, nil,
      &pixelBufferOut)
    guard err == noErr, let pixelBuffer = pixelBufferOut else {
      throw DummyVideoGeneratorError.pixelBufferCreationFailure
    }
    return pixelBuffer
  }

  func generateNextVideoFrame() throws -> VideoFrame {
    fillLumaPlane(frameIndex: frameIndex)
    fillChromaPlane(frameIndex: frameIndex)
    let pixelBuffer = try createPixelBuffer()

    let elapsedTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))
    let pts = CMTimeAdd(initialPTS, elapsedTime)

    frameIndex += 1

    return VideoFrame(pixelBuffer: pixelBuffer, pts: pts)
  }
}
