#import <CommonCrypto/CommonHMAC.h>
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

typedef struct VideoFrame {
  long width;
  long height;
  long lumaBytesPerRow;
  long chromaBytesPerRow;
  uint8_t *lumaData;
  uint8_t *chromaData;
} VideoFrame;

typedef struct AudioFrame {
  long numSamples;
  long numChannels;
  int16_t *data;
} AudioFrame;

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
  NSURL *baseURL =
      [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory
                                           inDomains:NSUserDomainMask][0];
  [NSFileManager.defaultManager createDirectoryAtURL:baseURL
                         withIntermediateDirectories:true
                                          attributes:nil
                                               error:nil];
  NSURL *fileURL = [baseURL URLByAppendingPathComponent:filename
                                            isDirectory:false];
  NSLog(@"The output file of this test case is %@", fileURL);
  return fileURL.path;
}

- (void)setUpDummyVideo {
  frameIndex = 0;
}

- (void)fillDummyVideoFrame:(VideoFrame *)frame {
  for (long y = 0; y < frame->height; y++) {
    for (long x = 0; x < frame->width; x++) {
      frame->lumaData[y * frame->lumaBytesPerRow + x] = x + y + frameIndex * 3;
    }
  }

  for (long y = 0; y < frame->height / 2; y++) {
    for (long x = 0; x < frame->width; x += 2) {
      frame->chromaData[y * frame->chromaBytesPerRow + x] =
          128 + y + frameIndex * 2;
      frame->chromaData[y * frame->chromaBytesPerRow + x + 1] =
          64 + x + frameIndex * 5;
    }
  }

  frameIndex++;
}

- (void)setUpDummyAudio:(const AudioInfo *)info {
  t = 0;
  tincr = 2 * M_PI * 330.0 / info->sampleRate;
  tincr2 = 2 * M_PI * 330.0 / info->sampleRate / info->sampleRate;
}

- (void)fillDummyAudioFrame:(AudioFrame *)frame isSwapped:(bool)isSwapped {
  long numSamples = frame->numSamples;
  long numChannels = frame->numChannels;
  for (long i = 0; i < numSamples; i++) {
    t += tincr;
    tincr += tincr2;
    int16_t value = sin(t) * 10000;
    if (isSwapped) {
      uint16_t uValue = CFSwapInt16HostToBig(*(uint16_t *)&value);
      value = *(int16_t *)&uValue;
    }
    for (long j = 0; j < numChannels; j++) {
      frame->data[i * numChannels + j] = value;
    }
  }
}

- (void)testVideoOnly {
  const VideoInfo info0 = {
      .width = 888,
      .height = 1920,
      .frameRate = 60,
      .bitRate = 8000000,
  };

  [self setUpDummyVideo];
  NSString *path = [self getOutputPath:@"testVideoOnly.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:info0.width
                                height:info0.height
                             frameRate:info0.frameRate
                               bitRate:info0.bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer startOutput]);

  for (int i = 0; i < 60; i++) {
    XCTAssertTrue([writer makeFrameWritable:0]);
    VideoFrame frame = {
        .width = [writer getWidth:0],
        .height = [writer getHeight:0],
        .lumaData = [writer getBaseAddress:0 ofPlane:0],
        .chromaData = [writer getBaseAddress:0 ofPlane:1],
        .lumaBytesPerRow = [writer getBytesPerRow:0 ofPlane:0],
        .chromaBytesPerRow = [writer getBytesPerRow:0 ofPlane:1],
    };
    [self fillDummyVideoFrame:&frame];

    XCTAssertTrue([writer writeVideo:0 outputPTS:i]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testAudioOnly {
  AudioInfo info0 = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyAudio:&info0];
  NSString *path = [self getOutputPath:@"testAudioOnly.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0.sampleRate
                               bitRate:info0.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  for (int i = 0; i < 43; i++) {
    AudioFrame frame = {
        .numSamples = 1024,
        .numChannels = 2,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame isSwapped:false];

    XCTAssertTrue([writer writeAudio:0
                           outputPTS:i * frame.numSamples
                              inData:(uint8_t *)frame.data
                             inCount:(int)frame.numSamples]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testSwappedAudioOnly {
  AudioInfo info0 = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyAudio:&info0];
  NSString *path = [self getOutputPath:@"testSwappedAudioOnly.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0.sampleRate
                               bitRate:info0.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  for (int i = 0; i < 43; i++) {
    AudioFrame frame = {
        .numSamples = 1024,
        .numChannels = 2,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame isSwapped:true];

    [writer swapInt16Bytes:(uint16_t *)frame.data
                      from:(uint16_t *)frame.data
                  numBytes:frame.numSamples * frame.numChannels * 2];
    XCTAssertTrue([writer writeAudio:0
                           outputPTS:i * frame.numSamples
                              inData:(uint8_t *)frame.data
                             inCount:(int)frame.numSamples]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testMuxedMedia {
  VideoInfo info0 = {
      .width = 888,
      .height = 1920,
      .frameRate = 60,
      .bitRate = 8000000,
  };

  AudioInfo info1 = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyVideo];
  [self setUpDummyAudio:&info1];
  NSString *path = [self getOutputPath:@"testMuxedMedia.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:info0.width
                                height:info0.height
                             frameRate:info0.frameRate
                               bitRate:info0.bitRate]);
  XCTAssertTrue([writer addAudioStream:1
                            sampleRate:info1.sampleRate
                               bitRate:info1.bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer openAudio:1]);
  XCTAssertTrue([writer startOutput]);

  int64_t nextAudioOutputPTS = 0;
  int64_t audioNumSamples = [writer getNumSamples:1];
  for (int64_t videoOutputPTS = 0; videoOutputPTS < 60; videoOutputPTS++) {
    XCTAssertTrue([writer makeFrameWritable:0]);

    VideoFrame frame = {
        .width = [writer getWidth:0],
        .height = [writer getHeight:0],
        .lumaData = [writer getBaseAddress:0 ofPlane:0],
        .chromaData = [writer getBaseAddress:0 ofPlane:1],
        .lumaBytesPerRow = [writer getBytesPerRow:0 ofPlane:0],
        .chromaBytesPerRow = [writer getBytesPerRow:0 ofPlane:1],
    };

    [self fillDummyVideoFrame:&frame];

    XCTAssertTrue([writer writeVideo:0 outputPTS:videoOutputPTS]);

    int64_t targetAudioOutputPTS =
        videoOutputPTS * info1.sampleRate / info0.frameRate;
    int16_t data[2048];
    for (int64_t audioOutputPTS = nextAudioOutputPTS;
         audioOutputPTS < targetAudioOutputPTS;
         audioOutputPTS += audioNumSamples) {
      AudioFrame frame = {
          .numSamples = audioNumSamples,
          .numChannels = 2,
          .data = data,
      };

      [self fillDummyAudioFrame:&frame isSwapped:false];

      XCTAssertTrue([writer writeAudio:1
                             outputPTS:audioOutputPTS
                                inData:(uint8_t *)frame.data
                               inCount:(int)frame.numSamples]);

      nextAudioOutputPTS = audioOutputPTS + audioNumSamples;
    }
  }

  [writer finishStream:0];
  [writer finishStream:1];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeStream:1];
  [writer closeOutput];
}

- (void)testStereoAudioWithResampling {
  AudioInfo info0dst = {
      .sampleRate = 48000,
      .bitRate = 320000,
      .numChannels = 2,
  };

  AudioInfo info0src = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyAudio:&info0src];
  NSString *path = [self getOutputPath:@"testAudioWithResampling.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0dst.sampleRate
                               bitRate:info0dst.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  for (int i = 0; i < 430; i++) {
    AudioFrame frame = {
        .numSamples = 1024,
        .numChannels = info0src.numChannels,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame isSwapped:false];
    int64_t outputPTS =
        i * frame.numSamples * info0dst.sampleRate / info0src.sampleRate;
    XCTAssertTrue([writer ensureResamplerIsInitialted:0
                                           sampleRate:info0src.sampleRate
                                          numChannels:info0src.numChannels]);
    XCTAssertTrue([writer writeAudio:0
                           outputPTS:outputPTS
                              inData:(uint8_t *)data
                             inCount:(int)frame.numSamples]);
    XCTAssertTrue([writer flushAudioWithResampling:0]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testSwappedStereoAudioWithResampling {
  AudioInfo info0dst = {
      .sampleRate = 48000,
      .bitRate = 320000,
      .numChannels = 2,
  };

  AudioInfo info0src = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyAudio:&info0src];
  NSString *path =
      [self getOutputPath:@"testSwappedStereoAudioWithResampling.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0dst.sampleRate
                               bitRate:info0dst.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048], swappedData[2048];
  for (int i = 0; i < 430; i++) {
    AudioFrame frame = {
        .numSamples = 1024,
        .numChannels = info0src.numChannels,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame isSwapped:true];
    int64_t outputPTS =
        i * frame.numSamples * info0dst.sampleRate / info0src.sampleRate;
    XCTAssertTrue([writer ensureResamplerIsInitialted:0
                                           sampleRate:info0src.sampleRate
                                          numChannels:info0src.numChannels]);

    [writer swapInt16Bytes:(uint16_t *)swappedData
                      from:(uint16_t *)data
                  numBytes:frame.numSamples * frame.numChannels * 2];
    XCTAssertTrue([writer writeAudio:0
                           outputPTS:outputPTS
                              inData:(uint8_t *)swappedData
                             inCount:(int)frame.numSamples]);
    XCTAssertTrue([writer flushAudioWithResampling:0]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testMonoAudioWithResampling {
  AudioInfo info0dst = {
      .sampleRate = 48000,
      .bitRate = 320000,
      .numChannels = 2,
  };

  AudioInfo info0src = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 1,
  };

  [self setUpDummyAudio:&info0src];
  NSString *path = [self getOutputPath:@"testMonoAudioWithResampling.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0dst.sampleRate
                               bitRate:info0dst.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  for (int i = 0; i < 215; i++) {
    AudioFrame frame = {
        .numSamples = 2048,
        .numChannels = info0src.numChannels,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame isSwapped:false];
    int64_t outputPTS =
        i * frame.numSamples * info0dst.sampleRate / info0src.sampleRate;
    XCTAssertTrue([writer ensureResamplerIsInitialted:0
                                           sampleRate:info0src.sampleRate
                                          numChannels:info0src.numChannels]);
    XCTAssertTrue([writer writeAudio:0
                           outputPTS:outputPTS
                              inData:(uint8_t *)data
                             inCount:(int)frame.numSamples]);
    XCTAssertTrue([writer flushAudioWithResampling:0]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testSwappedMonoAudioWithResampling {
  AudioInfo info0dst = {
      .sampleRate = 48000,
      .bitRate = 320000,
      .numChannels = 2,
  };

  AudioInfo info0src = {
      .sampleRate = 44100,
      .bitRate = 320000,
      .numChannels = 1,
  };

  [self setUpDummyAudio:&info0src];
  NSString *path =
      [self getOutputPath:@"testSwappedMonoAudioWithResampling.mp4"];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0dst.sampleRate
                               bitRate:info0dst.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048], swappedData[2048];
  for (int i = 0; i < 215; i++) {
    AudioFrame frame = {
        .numSamples = 2048,
        .numChannels = info0src.numChannels,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame isSwapped:true];
    int64_t outputPTS =
        i * frame.numSamples * info0dst.sampleRate / info0src.sampleRate;
    XCTAssertTrue([writer ensureResamplerIsInitialted:0
                                           sampleRate:info0src.sampleRate
                                          numChannels:info0src.numChannels]);
    [writer swapInt16Bytes:(uint16_t *)swappedData
                      from:(uint16_t *)data
                  numBytes:frame.numSamples * frame.numChannels * 2];
    XCTAssertTrue([writer writeAudio:0
                           outputPTS:outputPTS
                              inData:(uint8_t *)swappedData
                             inCount:(int)frame.numSamples]);
    XCTAssertTrue([writer flushAudioWithResampling:0]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}
@end
