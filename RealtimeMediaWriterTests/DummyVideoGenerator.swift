import CoreMedia
import CoreVideo
import Foundation

enum DummyVideoGeneratorError: Error {
  case pixelBufferPoolCreationFailure
  case pixelBufferCreationFailure
}

struct VideoFrame {
  let pixelBuffer: CVPixelBuffer
  let pts: CMTime
}

class DummyVideoGenerator {
  private let width: Int
  private let height: Int
  private let frameRate: Int
  private let initialPTS: CMTime

  private var frameIndex: Int = 0

  private let pixelBufferAttributes: CFDictionary
  private let pixelBufferPool: CVPixelBufferPool

  init(width: Int, height: Int, frameRate: Int, initialPTS: CMTime) throws {
    self.width = width
    self.height = height
    self.frameRate = frameRate
    self.initialPTS = initialPTS

    pixelBufferAttributes =
      [
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        kCVPixelBufferWidthKey: width as CFNumber,
        kCVPixelBufferHeightKey: height as CFNumber,
      ] as CFDictionary

    var pixelBufferPoolOut: CVPixelBufferPool?
    let err = CVPixelBufferPoolCreate(
      kCFAllocatorDefault, nil, pixelBufferAttributes, &pixelBufferPoolOut)
    guard err == noErr, let pixelBufferPool = pixelBufferPoolOut else {
      throw DummyVideoGeneratorError.pixelBufferPoolCreationFailure
    }
    self.pixelBufferPool = pixelBufferPool
  }

  private func fillLumaPlane(lumaData: UnsafeMutablePointer<UInt8>, bytesPerRow: Int, frameIndex: Int) {
    var yPos: Int = 0
    while yPos < height {
      var xPos: Int = 0
      while xPos < width {
        lumaData[yPos * bytesPerRow + xPos] = UInt8((xPos + yPos + frameIndex * 3) & 0xFF)
        xPos += 1
      }
      yPos += 1
    }
  }

  private func fillChromaPlane(chromaData: UnsafeMutablePointer<UInt8>, bytesPerRow: Int, frameIndex: Int) {
    var yPos: Int = 0
    while yPos < height / 2 {
      var xPos: Int = 0
      while xPos < width {
        chromaData[yPos * bytesPerRow + xPos] = UInt8((128 + yPos + frameIndex * 2) & 0xFF)
        chromaData[yPos * bytesPerRow + xPos + 1] = UInt8((64 + xPos + frameIndex * 5) & 0xFF)
        xPos += 1
      }
      yPos += 1
    }
  }

  func generateNextVideoFrame() throws -> VideoFrame {
    var pixelBufferOut: CVPixelBuffer?
    let err = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
      kCFAllocatorDefault, pixelBufferPool, pixelBufferAttributes, &pixelBufferOut)
    guard err == noErr, let pixelBuffer = pixelBufferOut else {
      print(err)
      throw DummyVideoGeneratorError.pixelBufferCreationFailure
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    let chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
    guard let lumaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
      let chromaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
    else {
      throw DummyVideoGeneratorError.pixelBufferCreationFailure
    }
    fillLumaPlane(lumaData: lumaData.assumingMemoryBound(to: UInt8.self), bytesPerRow: lumaBytesPerRow, frameIndex: frameIndex)
    fillChromaPlane(
      chromaData: chromaData.assumingMemoryBound(to: UInt8.self), bytesPerRow: chromaBytesPerRow, frameIndex: frameIndex)
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let elapsedTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))
    let pts = CMTimeAdd(initialPTS, elapsedTime)

    frameIndex += 1

    return VideoFrame(pixelBuffer: pixelBuffer, pts: pts)
  }
}
