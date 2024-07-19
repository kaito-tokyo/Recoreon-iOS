import CoreMedia
import CoreVideo
import Foundation

enum DummyVideoGeneratorError: Error {
  case pixelBufferPoolCreationFailure
  case pixelBufferCreationFailure
}

struct DummyVideoGeneratorFrame {
  let pixelBuffer: CVPixelBuffer
  let pts: CMTime
}

class DummyVideoGenerator {
  private let width: Int
  private let height: Int
  private let frameRate: Int
  private let initialPTS: CMTime

  private var frameIndex: Int = 0

  private let pixelBufferPool: CVPixelBufferPool

  init(width: Int, height: Int, frameRate: Int, initialPTS: CMTime) throws {
    self.width = width
    self.height = height
    self.frameRate = frameRate
    self.initialPTS = initialPTS

    let pixelBufferAttributes =
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

  func generateNextVideoFrame() throws -> DummyVideoGeneratorFrame {
    var pixelBufferOut: CVPixelBuffer?
    let err = CVPixelBufferPoolCreatePixelBuffer(
      kCFAllocatorDefault, pixelBufferPool, &pixelBufferOut)
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

    fillLumaPlane(lumaData, width, height, lumaBytesPerRow, frameIndex)
    fillChromaPlane(chromaData, width, height, chromaBytesPerRow, frameIndex)

    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let elapsedTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(frameRate))
    let pts = CMTimeAdd(initialPTS, elapsedTime)

    frameIndex += 1

    return DummyVideoGeneratorFrame(pixelBuffer: pixelBuffer, pts: pts)
  }
}
