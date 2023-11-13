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
                               bitRate:info0->frameRate]);
  XCTAssertTrue([writer addAudioStream:1 sampleRate:info1->sampleRate bitRate:info1->bitRate]);
  XCTAssertTrue([writer addAudioStream:2 sampleRate:info2->sampleRate bitRate:info2->bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer openAudio:1]);
  XCTAssertTrue([writer openAudio:2]);
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

- (void)writeSampleBufferToWriter:(ScreenRecordWriter *)writer sampleBuffer:(CMSampleBufferRef)sampleBuffer {
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

- (CMSampleBufferRef)createAudioSample:(AudioInfo *)info buf:(void *)buf bufSize:(uint32_t)bufSize pts:(int64_t)pts {
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
    .presentationTimeStamp = CMTimeMake(pts, info->sampleRate),
    .decodeTimeStamp = CMTimeMake(pts, info->sampleRate)
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
  VideoInfo info0 = {
    .width = 888,
    .height = 1920,
    .frameRate = 120,
  };
  AudioInfo info1 = {
    .sampleRate = 44100,
    .bitRate = 320000,
  };
  AudioInfo info2 = {
    .sampleRate = 48000,
    .bitRate = 320000,
  };

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *filename = [NSHomeDirectory() stringByAppendingString:@"/test2.mkv"];
  [self setupWriter:writer filename:filename info0:&info0 info1:&info1 info2:&info2];
  for (int i = 0; i < 60; i++) {
    CMSampleBufferRef sampleBuffer = [self createVideoSample:&info0 pts:i];
    [self writeSampleBufferToWriter:writer sampleBuffer:sampleBuffer];
  }
  [self finalizeWriter:writer];
}

//- (void)testPerformanceExample {
//  // This is an example of a performance test case.
//  [self measureBlock:^{
//      // Put the code you want to measure the time of here.
//  }];
//}

@end
