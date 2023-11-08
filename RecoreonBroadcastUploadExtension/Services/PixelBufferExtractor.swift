import MetalKit

class PixelBufferExtractor {
  struct Frame {
    let lumaData: UnsafeMutableRawPointer
    let chmoraData: UnsafeMutableRawPointer
    let lumaBytesPerRow: Int
    let chromaBytesPerRow: Int
    let height: Int
  }

  private let metalDevice: MTLDevice
  private let textureCache: CVMetalTextureCache
  private let commandQueue: MTLCommandQueue

  private var dstLumaBufferRef: MTLBuffer?
  private var dstChromaBufferRef: MTLBuffer?

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

  func extract(_ srcPixelBuffer: CVPixelBuffer, lumaBytesPerRow: Int, chromaBytesPerRow: Int)
    -> Frame?
  {  // swiftlint:disable:this opening_brace
    let pixelFormat = CVPixelBufferGetPixelFormatType(srcPixelBuffer)
    if pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
      return nil
    }

    let height = CVPixelBufferGetHeight(srcPixelBuffer)
    guard let dstLumaBuffer = getDstLumaBuffer(bytesPerRow: lumaBytesPerRow, height: height),
      let dstChromaBuffer = getDstChromaBuffer(bytesPerRow: chromaBytesPerRow, height: height)
    else { return nil }

    guard
      let srcLumaTexture = createTextureFromPixelBuffer(
        srcPixelBuffer, planeIndex: 0, format: .r8Unorm),
      let srcChromaTexture = createTextureFromPixelBuffer(
        srcPixelBuffer, planeIndex: 1, format: .rg8Unorm),
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeBlitCommandEncoder()
    else { return nil }
    encoder.copy(
      fromTexture: srcLumaTexture, sourceBytesPerRow: lumaBytesPerRow, toBuffer: dstLumaBuffer)
    encoder.copy(
      fromTexture: srcChromaTexture, sourceBytesPerRow: chromaBytesPerRow, toBuffer: dstChromaBuffer
    )
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    return Frame(
      lumaData: dstLumaBuffer.contents(), chmoraData: dstChromaBuffer.contents(),
      lumaBytesPerRow: lumaBytesPerRow, chromaBytesPerRow: chromaBytesPerRow, height: height)
  }

  private func getDstLumaBuffer(bytesPerRow: Int, height: Int) -> MTLBuffer? {
    if dstLumaBufferRef == nil {
      dstLumaBufferRef = metalDevice.makeBuffer(
        length: (bytesPerRow + 4) * (height + 4), options: .storageModeShared)
    }
    return dstLumaBufferRef
  }

  private func getDstChromaBuffer(bytesPerRow: Int, height: Int) -> MTLBuffer? {
    if dstChromaBufferRef == nil {
      dstChromaBufferRef = metalDevice.makeBuffer(
        length: (bytesPerRow + 4) * (height + 4) / 2, options: .storageModeShared)
    }
    return dstChromaBufferRef
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

extension MTLBlitCommandEncoder {
  fileprivate func copy(fromTexture: MTLTexture, sourceBytesPerRow: Int, toBuffer: MTLBuffer) {
    self.copy(
      from: fromTexture,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOriginMake(0, 0, 0),
      sourceSize: MTLSizeMake(fromTexture.width, fromTexture.height, 1),
      to: toBuffer,
      destinationOffset: 0,
      destinationBytesPerRow: sourceBytesPerRow,
      destinationBytesPerImage: 0
    )
  }
}
