#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonHMAC.h>

#import "../RecoreonBroadcastUploadExtension/ScreenRecordWriter.h"

typedef struct VideoInfo {
  int width;
  int height;
  int frameRate;
  int bitRate;
} VideoInfo;

typedef struct AudioInfo {
  int sampleRate;
  int bitRate;
  int numChannels;
} AudioInfo;


static VideoInfo screenVideoInfo0 = {
  .width = 888,
  .height = 1920,
  .frameRate = 60,
  .bitRate = 8000000,
};

static AudioInfo screenAudioInfo = {
  .sampleRate = 44100,
  .bitRate = 320000,
  .numChannels = 2,
};

static AudioInfo micAudioInfo0 = {
  .sampleRate = 48000,
  .bitRate = 320000,
  .numChannels = 2,
};

static AudioInfo micAudioInfo1 = {
  .sampleRate = 24000,
  .bitRate = 320000,
  .numChannels = 2,
};

static NSString *sha256sum(NSData *data) {
  uint8_t digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (int)data.length, digest);
  NSMutableString *result = [[NSMutableString alloc] init];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [result appendFormat:@"%02x", digest[i]];
  }
  return [result copy];
}

@interface ScreenRecordWriterTests : XCTestCase {
  double t;
  double tincr;
  double tincr2;
  int frameIndex;
}
@end

@implementation ScreenRecordWriterTests
- (void)setUp {
}

- (void)tearDown {
}

- (NSString *__nonnull)getOutputPath:(NSString *__nonnull)filename {
  NSURL *baseURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
  [NSFileManager.defaultManager createDirectoryAtURL:baseURL withIntermediateDirectories:true attributes:nil error:nil];
  NSURL *fileURL = [baseURL URLByAppendingPathComponent:filename isDirectory:false];
  NSLog(@"The output file of this test case is %@", fileURL);
  return fileURL.path;
}

- (void)setUpDummyVideo {
  frameIndex = 0;
}

- (void)fillDummyVideoFrame:(CMSampleBufferRef)sampleBuffer {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

  CVPixelBufferLockBaseAddress(pixelBuffer, 0);

  uint8_t *lumaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
  uint8_t *chromaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
  size_t lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
  size_t chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      lumaData[y * lumaBytesPerRow + x] = x + y + frameIndex * 3;
    }
  }

  for (int y = 0; y < height / 2; y++) {
    for (int x = 0; x < width; x += 2) {
      chromaData[y * chromaBytesPerRow + x] = 128 + y + frameIndex * 2;
      chromaData[y * chromaBytesPerRow + x + 1] = 64 + x + frameIndex * 5;
    }
  }

  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

  frameIndex++;
}

- (void)setUpDummyAudio:(AudioInfo *)info {
  t = 0;
  tincr = 2 * M_PI * 330.0 / info->sampleRate;
  tincr2 = 2 * M_PI * 330.0 / info->sampleRate / info->sampleRate;
}

- (int16_t)getDummyAudioSample {
  t += tincr;
  tincr += tincr2;
  return sin(t) * 10000;
}

- (CMSampleBufferRef)createVideoSample:(VideoInfo *)info {
  CVPixelBufferRef pixelBuffer;
  CVPixelBufferCreate(NULL, info->width, info->height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, NULL, &pixelBuffer);

  CMVideoFormatDescriptionRef format;
  CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &format);

  CMSampleTimingInfo timing = {
    .duration = CMTimeMake(1, info->frameRate),
    .presentationTimeStamp = CMTimeMake(0, info->frameRate),
    .decodeTimeStamp = CMTimeMake(0, info->frameRate)
  };

  CMSampleBufferRef sampleBuffer;
  XCTAssertEqual(CMSampleBufferCreateForImageBuffer(NULL, pixelBuffer, TRUE, NULL, NULL, format, &timing, &sampleBuffer), noErr);
  return sampleBuffer;
}

- (void)writeVideoSampleToWriter:(ScreenRecordWriter *)writer index:(int)index sampleBuffer:(CMSampleBufferRef)sampleBuffer outputPTS:(int64_t)outputPTS {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

  CVPixelBufferLockBaseAddress(pixelBuffer, 0);

  void *lumaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
  void *chromaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
  size_t lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
  size_t chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  [writer writeVideo:index lumaData:lumaData chromaData:chromaData lumaBytesPerRow:lumaBytesPerRow chromaBytesPerRow:chromaBytesPerRow height:height outputPTS:outputPTS];

  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (CMSampleBufferRef)createAudioSample:(AudioInfo *)info buf:(void *)buf bufSize:(uint32_t)bufSize {
  int numSamples = bufSize / info->numChannels / 2;

  AudioStreamBasicDescription asbd = {
    .mSampleRate = info->sampleRate,
    .mFormatID = kAudioFormatLinearPCM,
    .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
    .mBytesPerPacket = 2 * info->numChannels,
    .mFramesPerPacket = 1,
    .mBytesPerFrame = 2 * info->numChannels,
    .mChannelsPerFrame = info->numChannels,
    .mBitsPerChannel = 16
  };

  CMFormatDescriptionRef format;
  XCTAssertEqual(CMAudioFormatDescriptionCreate(NULL, &asbd, 0, NULL, 0, NULL, NULL, &format), noErr);

  CMSampleTimingInfo timing = {
    .duration = CMTimeMake(1, info->sampleRate),
    .presentationTimeStamp = CMTimeMake(0, info->sampleRate),
    .decodeTimeStamp = CMTimeMake(0, info->sampleRate)
  };

  CMSampleBufferRef sampleBuffer;
  XCTAssertEqual(CMSampleBufferCreate(NULL, NULL, false, NULL, NULL, format, numSamples, 1, &timing, 0, NULL, &sampleBuffer), noErr);

  AudioBufferList audioBufferList;
  audioBufferList.mNumberBuffers = 1;
  audioBufferList.mBuffers[0].mData = buf;
  audioBufferList.mBuffers[0].mDataByteSize = bufSize;
  audioBufferList.mBuffers[0].mNumberChannels = info->numChannels;

  XCTAssertEqual(CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer, NULL, NULL, 0, &audioBufferList), noErr);

  return sampleBuffer;
}

- (void)writeAudioSampleToWriter:(ScreenRecordWriter *)writer index:(int)index sampleBuffer:(CMSampleBufferRef)sampleBuffer outputPTS:(int64_t)outputPTS {
  AudioBufferList abl;
  CMBlockBufferRef blockBuffer;
  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &abl, sizeof(AudioBufferList), NULL, NULL, 0, &blockBuffer);
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format);
  [writer writeAudio:index abl:&abl asbd:asbd outputPTS:outputPTS];
}

- (void)testVideoFrame {
  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testVideoFrame.mp4"];
  VideoInfo *info0 = &screenVideoInfo0;

  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addVideoStream:0 width:info0->width height:info0->height frameRate:info0->frameRate bitRate:info0->bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer startOutput]);

  for (int i = 0; i < 60; i++) {
    CMSampleBufferRef sampleBuffer = [self createVideoSample:info0];
    [self fillDummyVideoFrame:sampleBuffer];
    [self writeVideoSampleToWriter:writer index:0 sampleBuffer:sampleBuffer outputPTS:i];
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer freeStream:0];
  [writer freeOutput];

  NSData *outputData = [NSData dataWithContentsOfFile:path];
  XCTAssertEqualObjects(sha256sum(outputData), @"291f7c360dc01856580fc8c40fe3ce2cfc00f8a647326da1a88a3daa1bd6dcb6");
}

- (void)testSameSampleRateAudio {
  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testSameSampleRateAudio.mp4"];
  AudioInfo *info0 = &screenAudioInfo;

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0 sampleRate:info0->sampleRate bitRate:info0->bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  int numSamples = sizeof(data) / sizeof(int16_t) / 2;
  [self setUpDummyAudio:info0];
  for (int i = 0; i < 43; i++) {
    for (int j = 0; j < numSamples; j++) {
      data[j * 2] = data[j * 2 + 1] = [self getDummyAudioSample];
    }
    int64_t outputPTS = i * numSamples;
    CMSampleBufferRef sampleBuffer = [self createAudioSample:info0 buf:data bufSize:sizeof(data)];
    [self writeAudioSampleToWriter:writer index:0 sampleBuffer:sampleBuffer outputPTS:outputPTS];
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer freeStream:0];
  [writer freeOutput];

  NSData *outputData = [NSData dataWithContentsOfFile:path];
  XCTAssertEqualObjects(sha256sum(outputData), @"efcbbf358a000a485980641140c7c625ea01ae20de1e2f6c8dbe40b7cf645c94");
}

- (void)testResampledAudio {
  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testResampledAudio.mp4"];
  AudioInfo *info0In = &micAudioInfo1;
  AudioInfo *info0Out = &micAudioInfo0;

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0 sampleRate:info0Out->sampleRate bitRate:info0Out->bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  int numSamples = sizeof(data) / sizeof(int16_t) / 2;
  [self setUpDummyAudio:info0In];
  for (int i = 0; i < 23; i++) {
    for (int j = 0; j < numSamples; j++) {
      data[j * 2] = data[j * 2 + 1] = [self getDummyAudioSample];
    }
    int64_t outputPTS = i * numSamples * info0Out->sampleRate / info0In->sampleRate;
    CMSampleBufferRef sampleBuffer = [self createAudioSample:info0In buf:data bufSize:sizeof(data)];
    [self writeAudioSampleToWriter:writer index:0 sampleBuffer:sampleBuffer outputPTS:outputPTS];
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer freeStream:0];
  [writer freeOutput];

  NSData *outputData = [NSData dataWithContentsOfFile:path];
  XCTAssertEqualObjects(sha256sum(outputData), @"924006554e0864a07cf720a5717fb5e2e1c0ddc5195121a3063802e4d7d23bbd");
}

@end
