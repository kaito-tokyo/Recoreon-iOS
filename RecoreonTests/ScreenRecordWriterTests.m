//
//  RecordWriterTests.m
//  RecoreonTests
//
//  Created by Kaito Udagawa on 2023/11/13.
//

#import <XCTest/XCTest.h>

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

static VideoInfo info0 = {
  .width = 888,
  .height = 1920,
  .frameRate = 120,
  .bitRate = 8000000,
};

static AudioInfo info1 = {
  .sampleRate = 44100,
  .bitRate = 320000,
  .numChannels = 2,
};

static AudioInfo info2 = {
  .sampleRate = 48000,
  .bitRate = 320000,
  .numChannels = 2,
};

static AudioInfo screenAudioinfo = {
  .sampleRate = 44100,
  .bitRate = 320000,
  .numChannels = 2,
};

@interface ScreenRecordWriterTests : XCTestCase
@end

@implementation ScreenRecordWriterTests
- (void)setUp {
  // Put setup code here. This method is called before the invocation of each
  // test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each
  // test method in the class.
}

- (void)setupWriter:(ScreenRecordWriter *)writer filename:(NSString *__nonnull)filename info0:(VideoInfo *__nonnull)info0 info1:(AudioInfo *)info1 info2:(AudioInfo *)info2{
  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:filename]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:info0->width
                                height:info0->height
                             frameRate:info0->frameRate
                               bitRate:info0->bitRate]);
  XCTAssertTrue([writer addAudioStream:1 sampleRate:info1->sampleRate bitRate:info1->bitRate]);
  XCTAssertTrue([writer addAudioStream:2 sampleRate:info2->sampleRate bitRate:info2->bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer openAudio:1]);
  XCTAssertTrue([writer openAudio:2]);
  XCTAssertTrue([writer startOutput]);
}

- (void)setupWriterWithOneAudio:(ScreenRecordWriter *)writer filename:(NSString *__nonnull)filename info0:(AudioInfo *__nonnull)info0 {
  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:filename]);
  XCTAssertTrue([writer addAudioStream:0 sampleRate:info0->sampleRate bitRate:info0->bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);
}

- (CMSampleBufferRef)createVideoSample:(VideoInfo *)info pts:(int64_t)pts {
  CVPixelBufferRef pixelBuffer;
  CVPixelBufferCreate(NULL, info->width, info->height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, NULL, &pixelBuffer);

  CMVideoFormatDescriptionRef format;
  CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &format);

  CMSampleTimingInfo timing = {
    .duration = CMTimeMake(1, info->frameRate),
    .presentationTimeStamp = CMTimeMake(pts, info->frameRate),
    .decodeTimeStamp = CMTimeMake(pts, info->frameRate)
  };

  CMSampleBufferRef sampleBuffer;
  XCTAssertEqual(CMSampleBufferCreateForImageBuffer(NULL, pixelBuffer, TRUE, NULL, NULL, format, &timing, &sampleBuffer), noErr);
  return sampleBuffer;
}

- (void)writeVideoSampleToWriter:(ScreenRecordWriter *)writer sampleBuffer:(CMSampleBufferRef)sampleBuffer {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

  CVPixelBufferLockBaseAddress(pixelBuffer, 0);

  void *lumaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
  void *chromaData = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
  size_t lumaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
  size_t chromaBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

  [writer writeVideo:0 lumaData:lumaData chromaData:chromaData lumaBytesPerRow:lumaBytesPerRow chromaBytesPerRow:chromaBytesPerRow height:height pts:pts];

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

- (void)writeAudioSampleToWriter:(ScreenRecordWriter *)writer index:(int)index sampleBuffer:(CMSampleBufferRef)sampleBuffer outputPts:(int64_t)outputPts {
  AudioBufferList abl;
  CMBlockBufferRef blockBuffer;
  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &abl, sizeof(AudioBufferList), NULL, NULL, 0, &blockBuffer);
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format);
  [writer writeAudio:index abl:&abl asbd:asbd outputPts:outputPts];
}

- (void)finalizeWriterWithOneAudio:(ScreenRecordWriter *)writer {
  [writer finishStream:0];

  [writer finishOutput];
  [writer freeStream:0];
  [writer freeOutput];
}

- (void)finalizeWriter:(ScreenRecordWriter *)writer {
  [writer finishStream:0];
  [writer finishStream:1];
  [writer finishStream:2];

  [writer finishOutput];
  [writer freeStream:0];
  [writer freeStream:1];
  [writer freeStream:2];
  [writer freeOutput];
}

- (void)testEmptyVideo {
  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *filename = [NSHomeDirectory() stringByAppendingString:@"/test2.mkv"];
  [self setupWriter:writer filename:filename info0:&info0 info1:&info1 info2:&info2];
  for (int i = 0; i < 60; i++) {
    CMSampleBufferRef sampleBuffer = [self createVideoSample:&info0 pts:i];
    [self writeVideoSampleToWriter:writer sampleBuffer:sampleBuffer];
  }
  uint8_t data[4096];
  CMSampleBufferRef sampleBuffer1 = [self createAudioSample:&info1 buf:data bufSize:4096];
  [self writeAudioSampleToWriter:writer index:1 sampleBuffer:sampleBuffer1 outputPts:0];
  [self writeAudioSampleToWriter:writer index:2 sampleBuffer:sampleBuffer1 outputPts:0];
  [self finalizeWriter:writer];
}

- (void)testSineAudio {
  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *filename = [NSHomeDirectory() stringByAppendingString:@"/testSineAudio.mkv"];
  NSLog(@"%@", filename);
  AudioInfo *info0 = &screenAudioinfo;

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:filename]);
  XCTAssertTrue([writer addAudioStream:0 sampleRate:info0->sampleRate bitRate:info0->bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  for (int i = 0; i < 43; i++) {
    int16_t data[2048];
    for (int j = 0; j < 1024; j++) {
      int n = j + i * 1024;
      data[j * 2] = data[j * 2 + 1] = sin(2 * M_PI * n * 1000.0 / info0->sampleRate) * 10000;
    }
    int64_t pts = i * 1024;
    CMSampleBufferRef sampleBuffer = [self createAudioSample:&screenAudioinfo buf:data bufSize:4096];
    [self writeAudioSampleToWriter:writer index:0 sampleBuffer:sampleBuffer outputPts:pts];
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer freeStream:0];
  [writer freeOutput];
}

- (void)testSampleRateChange {
  AudioInfo info21 = {
    .sampleRate = 96000,
    .bitRate = 320000,
    .numChannels = 2,
  };

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];
  NSString *filename = [NSHomeDirectory() stringByAppendingString:@"/test2.mkv"];
  [self setupWriter:writer filename:filename info0:&info0 info1:&info1 info2:&info2];

  int16_t dataIn[2048];
  dataIn[0] = 150;
  dataIn[1] = 300;
  CMSampleBufferRef sampleBuffer = [self createAudioSample:&info21 buf:dataIn bufSize:4096];
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
  const AudioStreamBasicDescription *inASBD = CMAudioFormatDescriptionGetStreamBasicDescription(format);

  [writer ensureAudioConverterAvailable:2 asbd:inASBD];

  int16_t dataOut[2048];
  uint32_t numSamples = 1024;
  AudioBufferList abl;
  abl.mNumberBuffers = 1;
  abl.mBuffers[0].mNumberChannels = 2;
  abl.mBuffers[0].mDataByteSize = 4096;
  abl.mBuffers[0].mData = dataOut;

  [writer listenToResampleAudioFrame:2 numSamples:&numSamples fillBufList:&abl];

  NSLog(@"0: %d", dataOut[0]);
  NSLog(@"1: %d", dataOut[1]);
  NSLog(@"1: %d", dataOut[2]);
  NSLog(@"1: %d", dataOut[3]);
  NSLog(@"1: %d", dataOut[4]);
  NSLog(@"1: %d", dataOut[5]);
  NSLog(@"1: %d", dataOut[6]);
  NSLog(@"1: %d", dataOut[7]);
  NSLog(@"1: %d", dataOut[8]);
  NSLog(@"1: %d", dataOut[9]);
}

@end
