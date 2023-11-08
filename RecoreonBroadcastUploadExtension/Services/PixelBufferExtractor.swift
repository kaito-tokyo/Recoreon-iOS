import MetalKit

class PixelBufferExtractor {
  private let metalDevice: MTLDevice
  private let textureCache: CVMetalTextureCache
  private let commandQueue: MTLCommandQueue

  private var newPixelBufferRef: CVPixelBuffer?

  init?() {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }

    var cacheRef: CVMetalTextureCache?
    CVMetalTextureCacheCreate(nil, nil, device, nil, &cacheRef)
    guard let cache = cacheRef else { return nil }

    guard let queue = device.makeCommandQueue() else { return nil }

    self.metalDevice = device
    self.textureCache = cache
    self.commandQueue = queue
  }

  func checkIfNewPixelBufferShouldBeRecreated(_ origWidth: Int, _ origHeight: Int) -> Bool {
    guard let newPixelBuffer = newPixelBufferRef else { return true }
    let newWidth = CVPixelBufferGetWidth(newPixelBuffer)
    let newHeight = CVPixelBufferGetHeight(newPixelBuffer)
    return newWidth != origWidth || newHeight != origHeight
  }

  func extract(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    if pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
      return nil
    }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    if checkIfNewPixelBufferShouldBeRecreated(width, height) {
      var attributes: [NSString: NSObject] = [:]
      attributes[kCVPixelBufferIOSurfacePropertiesKey] = [AnyHashable: Any]() as NSObject
      CVPixelBufferCreate(
        kCFAllocatorDefault, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        attributes as CFDictionary?, &newPixelBufferRef)
    }
    guard let newPixelBuffer = newPixelBufferRef else { return nil }

    guard
      let srcLumaTexture = createTextureFromPixelBuffer(
        pixelBuffer, planeIndex: 0, format: .r8Unorm)
    else { return nil }
    guard
      let srcChromaTexture = createTextureFromPixelBuffer(
        pixelBuffer, planeIndex: 1, format: .rg8Unorm)
    else { return nil }
    guard
      let dstLumaTexture = createTextureFromPixelBuffer(
        newPixelBuffer, planeIndex: 0, format: .r8Unorm)
    else { return nil }
    guard
      let dstChromaTexture = createTextureFromPixelBuffer(
        newPixelBuffer, planeIndex: 1, format: .rg8Unorm)
    else { return nil }

    guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
    guard let encoder = commandBuffer.makeBlitCommandEncoder() else { return nil }
    encoder.copy(from: srcLumaTexture, to: dstLumaTexture)
    encoder.copy(from: srcChromaTexture, to: dstChromaTexture)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    return newPixelBuffer
  }

  func createTextureFromPixelBuffer(
    _ pixelBuffer: CVPixelBuffer, planeIndex: Int, format: MTLPixelFormat
  ) -> MTLTexture? {
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

    var textureRef: CVMetalTexture?
    let ret = CVMetalTextureCacheCreateTextureFromImage(
      kCFAllocatorDefault, textureCache, pixelBuffer, nil, format, width, height, planeIndex,
      &textureRef)
    if ret == kCVReturnSuccess {
      if let texture = textureRef {
        return CVMetalTextureGetTexture(texture)
      }
    }
    return nil
  }
}
