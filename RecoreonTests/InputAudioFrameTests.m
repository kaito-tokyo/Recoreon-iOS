#import <XCTest/XCTest.h>

#import "../RecoreonBroadcastUploadExtension/InputAudioFrame.h"

@interface InputAudioFrameTests : XCTestCase
@end

@implementation InputAudioFrameTests

- (void)setUp {
}

- (void)tearDown {
}

- (CMSampleBufferRef)createInt16AudioSampleBuffer:(uint8_t *)buf bufSize:(uint32_t)bufSize numChannels:(int)numChannels sampleRate:(double)sampleRate isBigEndian:(BOOL)isBigEndian {
  int numSamples = bufSize / numChannels / 2;

  AudioStreamBasicDescription asbd = {
    .mSampleRate = sampleRate,
    .mFormatID = kAudioFormatLinearPCM,
    .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
    .mBytesPerPacket = 2 * numChannels,
    .mFramesPerPacket = 1,
    .mBytesPerFrame = 2 * numChannels,
    .mChannelsPerFrame = numChannels,
    .mBitsPerChannel = 16
  };
  if (isBigEndian) {
    asbd.mFormatFlags |= kAudioFormatFlagIsBigEndian;
  }

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
  audioBufferList.mBuffers[0].mData = buf;
  audioBufferList.mBuffers[0].mDataByteSize = bufSize;
  audioBufferList.mBuffers[0].mNumberChannels = numChannels;

  XCTAssertEqual(CMSampleBufferSetDataBufferFromAudioBufferList(sampleBuffer, NULL, NULL, 0, &audioBufferList), noErr);

  return sampleBuffer;
}
- (void)testInitWithSampleBuffer {
  uint8_t buf[4096];
  CMSampleBufferRef sampleBuffer = [self createInt16AudioSampleBuffer:buf bufSize:4096 numChannels:2 sampleRate:44100 isBigEndian:true];
  InputAudioFrame *inputFrame = [[InputAudioFrame alloc] initWithSampleBuffer:sampleBuffer sampleRate:44100];
  XCTAssertNotNil(inputFrame);
}

@end
