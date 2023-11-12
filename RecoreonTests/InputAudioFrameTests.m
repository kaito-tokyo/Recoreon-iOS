#import <XCTest/XCTest.h>

#import "../RecoreonBroadcastUploadExtension/InputAudioFrame.h"

@interface InputAudioFrameTests : XCTestCase
@end

@implementation InputAudioFrameTests

- (void)setUp {
}

- (void)tearDown {
}

- (void)testInitWithSampleBuffer {
  uint8_t dataBuf[4096];
  const CMItemCount numSamples = 1024;
  double sampleRate = 44100;

//  CMBlockBufferRef blockBuffer;
//  CMBlockBufferCreateWithMemoryBlock(NULL, NULL, bufSize, NULL, NULL, 0, bufSize, 0, &blockBuffer);
//  CMBlockBufferAssureBlockMemory(blockBuffer);
//  CMSampleBufferCreate(NULL, blockBuffer, true, NULL, NULL, NULL, numSamples, 0, NULL, 0, NULL, &sampleBuffer);

  AudioStreamBasicDescription asbd = {
    .mSampleRate = sampleRate,
    .mFormatID = kAudioFormatLinearPCM,
    .mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
    .mBytesPerPacket = 4,
    .mFramesPerPacket = 1,
    .mBytesPerFrame = 4,
    .mChannelsPerFrame = 2,
    .mBitsPerChannel = 16
  };

  CMFormatDescriptionRef format;
  XCTAssertEqual(CMAudioFormatDescriptionCreate(NULL, &asbd, 0, NULL, 0, NULL, NULL, &format), noErr);

  CMSampleTimingInfo timing = {
    .duration = CMTimeMake(1, sampleRate),
    .presentationTimeStamp = CMTimeMake(0, 1),
    .decodeTimeStamp = CMTimeMake(0, 1)
  };

  CMSampleBufferRef sampleBuffer;
  XCTAssertEqual(CMSampleBufferCreate(NULL, NULL, false, NULL, NULL, format, numSamples, 1, &timing, 0, NULL, &sampleBuffer), noErr);

  AudioBufferList audioBufferList;
  audioBufferList.mNumberBuffers = 1;
  audioBufferList.mBuffers[0].mData = dataBuf;
  audioBufferList.mBuffers[0].mDataByteSize = sizeof(dataBuf);
  audioBufferList.mBuffers[0].mNumberChannels = 2;

  XCTAssertEqual(CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer, NULL, NULL, 0, &audioBufferList), noErr);
  InputAudioFrame *inputFrame = [[InputAudioFrame alloc] initWithSampleBuffer:sampleBuffer sampleRate:44100];
  XCTAssertNotNil(inputFrame);
}

- (void)testPerformanceExample {
  // This is an example of a performance test case.
  [self measureBlock:^{
      // Put the code you want to measure the time of here.
  }];
}

@end
