import MetalKit

class PixelBufferExtractor {
  struct Frame {
    let width: Int
    let height: Int
    let lumaBytesPerRow: Int
    let chromaBytesPerRow: Int
    let lumaData: UnsafeRawPointer
    let chromaData: UnsafeRawPointer
  }

  private let metalDevice: MTLDevice
  private let textureCache: CVMetalTextureCache
  private let commandQueue: MTLCommandQueue

  private let lumaBuffer: MTLBuffer
  private let chromaBuffer: MTLBuffer

  init?(height: Int, lumaBytesPerRow: Int, chromaBytesPerRow: Int) {
    guard let device = MTLCreateSystemDefaultDevice() else { return nil }

    var cacheRef: CVMetalTextureCache?
    CVMetalTextureCacheCreate(nil, nil, device, nil, &cacheRef)
    guard let cache = cacheRef else { return nil }

    guard let queue = device.makeCommandQueue() else { return nil }

    let lumaLength = (lumaBytesPerRow + 4) * (height + 4)
    let chromaLength = (chromaBytesPerRow + 4) * (height + 4)

    guard
      let lumaBuffer = device.makeBuffer(length: lumaLength, options: .storageModeShared),
      let chromaBuffer = device.makeBuffer(length: chromaLength, options: .storageModeShared)
    else { return nil }

    metalDevice = device
    textureCache = cache
    commandQueue = queue
    self.lumaBuffer = lumaBuffer
    self.chromaBuffer = chromaBuffer
  }

  func extract(_ pixelBuffer: CVPixelBuffer) -> Frame? {
    let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
    if format != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
      return nil
    }

    guard
      let lumaTexture = createTextureFromPixelBuffer(pixelBuffer, 0, .r8Unorm),
      let chromaTexture = createTextureFromPixelBuffer(pixelBuffer, 1, .rg8Unorm),
      let commandBuffer = commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeBlitCommandEncoder()
    else { return nil }

    let lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
    let chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

    encoder.copy(fromTexture: lumaTexture, bytesPerRow: lumaBytesPerRow, toBuffer: lumaBuffer)
    encoder.copy(fromTexture: chromaTexture, bytesPerRow: chromaBytesPerRow, toBuffer: chromaBuffer)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    let frame = Frame(
      width: width,
      height: height,
      lumaBytesPerRow: lumaBytesPerRow,
      chromaBytesPerRow: chromaBytesPerRow,
      lumaData: lumaBuffer.contents(),
      chromaData: chromaBuffer.contents()
    )

    return frame
  }

  private func createTextureFromPixelBuffer(
    _ pixelBuffer: CVPixelBuffer, _ planeIndex: Int, _ format: MTLPixelFormat
  ) -> MTLTexture? {
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

    var textureRef: CVMetalTexture?
    let ret = CVMetalTextureCacheCreateTextureFromImage(
      nil, textureCache, pixelBuffer, nil, format, width, height, planeIndex,
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
  fileprivate func copy(fromTexture: MTLTexture, bytesPerRow: Int, toBuffer: MTLBuffer) {
    self.copy(
      from: fromTexture,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOriginMake(0, 0, 0),
      sourceSize: MTLSizeMake(fromTexture.width, fromTexture.height, 1),
      to: toBuffer,
      destinationOffset: 0,
      destinationBytesPerRow: bytesPerRow,
      destinationBytesPerImage: 0
    )
  }
}
