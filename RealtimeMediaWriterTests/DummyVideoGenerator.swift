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
    var yPos: Int = 0
    var xPos: Int = 0
    while yPos < height {
      while xPos < width {
        lumaData[yPos * bytesPerRow + xPos] = UInt8((xPos + yPos + frameIndex * 3) & 0xFF)
        xPos += 1
      }
      yPos += 1
    }
  }

  private func fillChromaPlane(frameIndex: Int) {
    var yPos: Int = 0
    var xPos: Int = 0
    while yPos < height / 2 {
      while xPos < width {
        chromaData[yPos * bytesPerRow + xPos] = UInt8((128 + yPos + frameIndex * 2) & 0xFF)
        chromaData[yPos * bytesPerRow + xPos + 1] = UInt8((64 + xPos + frameIndex * 5) & 0xFF)
        xPos += 1
      }
      yPos += 1
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
