import MetalKit

class PixelBufferExtractor {
  private let metalDevice: MTLDevice
  private let textureCache: CVMetalTextureCache
  private let commandQueue: MTLCommandQueue

  private var dstPixelBufferRef: CVPixelBuffer?

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

  func extract(_ srcPixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
    if pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
      return nil
    }

    guard let dstPixelBuffer = getDstPixelBuffer(srcPixelBuffer) else { return nil }

    guard
      let srcLumaTexture = createTextureFromPixelBuffer(
        srcPixelBuffer, planeIndex: 0, format: .r8Unorm)
    else { return nil }
    guard
      let srcChromaTexture = createTextureFromPixelBuffer(
        srcPixelBuffer, planeIndex: 1, format: .rg8Unorm)
    else { return nil }
    guard
      let dstLumaTexture = createTextureFromPixelBuffer(
        dstPixelBuffer, planeIndex: 0, format: .r8Unorm)
    else { return nil }
    guard
      let dstChromaTexture = createTextureFromPixelBuffer(
        dstPixelBuffer, planeIndex: 1, format: .rg8Unorm)
    else { return nil }

    guard let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }
    guard let encoder = commandBuffer.makeBlitCommandEncoder() else { return nil }
    encoder.copy(from: srcLumaTexture, to: dstLumaTexture)
    encoder.copy(from: srcChromaTexture, to: dstChromaTexture)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    return dstPixelBuffer
  }

  private func allocatePixelBuffer(_ width: Int, _ height: Int, _ format: OSType) -> CVPixelBuffer? {
    var pixelBufferRef: CVPixelBuffer?
    var attributes: [NSString: NSObject] = [:]
    attributes[kCVPixelBufferIOSurfacePropertiesKey] = [AnyHashable: Any]() as NSObject
    CVPixelBufferCreate(nil, width, height, format, attributes as CFDictionary?, &pixelBufferRef)
    return pixelBufferRef
  }

  private func getDstPixelBuffer(_ srcPixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let srcWidth = CVPixelBufferGetWidth(srcPixelBuffer)
    let srcHeight = CVPixelBufferGetHeight(srcPixelBuffer)
    let format = CVPixelBufferGetPixelFormatType(srcPixelBuffer)

    if let dstPixelBuffer = dstPixelBufferRef {
      let dstWidth = CVPixelBufferGetWidth(dstPixelBuffer)
      let dstHeight = CVPixelBufferGetHeight(dstPixelBuffer)
      if dstWidth != srcWidth || dstHeight != srcHeight {
        dstPixelBufferRef = nil
        dstPixelBufferRef = allocatePixelBuffer(srcWidth, srcHeight, format)
      }
    } else {
      dstPixelBufferRef = nil
      dstPixelBufferRef = allocatePixelBuffer(srcWidth, srcHeight, format)
    }
    return dstPixelBufferRef
  }

  private func createTextureFromPixelBuffer(
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
