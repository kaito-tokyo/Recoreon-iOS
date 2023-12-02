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

- (void)setUpDummyAudio:(AudioInfo *)info {
  t = 0;
  tincr = 2 * M_PI * 330.0 / info->sampleRate;
  tincr2 = 2 * M_PI * 330.0 / info->sampleRate / info->sampleRate;
}

- (void)fillDummyAudioFrame:(AudioFrame *)frame {
  for (long i = 0; i < frame->numSamples * 2; i += 2) {
    t += tincr;
    tincr += tincr2;
    frame->data[i] = frame->data[i + 1] = sin(t) * 10000;
  }
}

- (void)testVideoFrame {
  [self setUpDummyVideo];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testVideoFrame.mp4"];
  VideoInfo *info0 = &screenVideoInfo0;

  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:info0->width
                                height:info0->height
                             frameRate:info0->frameRate
                               bitRate:info0->bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer startOutput]);

  for (int i = 0; i < 60; i++) {
    XCTAssertTrue([writer makeFrameWritable:0]);
    VideoFrame frame;
    frame.width = [writer getWidth:0];
    frame.height = [writer getHeight:0];
    frame.lumaData = [writer getBaseAddress:0 ofPlane:0];
    frame.chromaData = [writer getBaseAddress:0 ofPlane:1];
    frame.lumaBytesPerRow = [writer getBytesPerRow:0 ofPlane:0];
    frame.chromaBytesPerRow = [writer getBytesPerRow:0 ofPlane:1];

    [self fillDummyVideoFrame:&frame];

    XCTAssertTrue([writer writeVideo:0 outputPTS:i]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testAudioFrame {
  AudioInfo *info0 = &screenAudioInfo;
  [self setUpDummyAudio:info0];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testAudioFrame.mp4"];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0->sampleRate
                               bitRate:info0->bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  for (int i = 0; i < 43; i++) {
    XCTAssertTrue([writer makeFrameWritable:0]);
    AudioFrame frame;
    frame.numSamples = [writer getNumSamples:0];
    frame.data = [writer getBaseAddress:0 ofPlane:0];

    [self fillDummyAudioFrame:&frame];

    XCTAssertTrue([writer writeAudio:0 outputPTS:i * frame.numSamples]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testMuxedVideo {
  VideoInfo *info0 = &screenVideoInfo0;
  AudioInfo *info1 = &screenAudioInfo;

  [self setUpDummyVideo];
  [self setUpDummyAudio:info1];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testMuxedVideo.mp4"];

  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:info0->width
                                height:info0->height
                             frameRate:info0->frameRate
                               bitRate:info0->bitRate]);
  XCTAssertTrue([writer addAudioStream:1
                            sampleRate:info1->sampleRate
                               bitRate:info1->bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer openAudio:1]);
  XCTAssertTrue([writer startOutput]);

  int64_t nextAudioOutputPTS = 0;
  int64_t audioNumSamples = [writer getNumSamples:1];
  for (int64_t videoOutputPTS = 0; videoOutputPTS < 60; videoOutputPTS++) {
    XCTAssertTrue([writer makeFrameWritable:0]);
    VideoFrame frame;
    frame.width = [writer getWidth:0];
    frame.height = [writer getHeight:0];
    frame.lumaData = [writer getBaseAddress:0 ofPlane:0];
    frame.chromaData = [writer getBaseAddress:0 ofPlane:1];
    frame.lumaBytesPerRow = [writer getBytesPerRow:0 ofPlane:0];
    frame.chromaBytesPerRow = [writer getBytesPerRow:0 ofPlane:1];

    [self fillDummyVideoFrame:&frame];

    XCTAssertTrue([writer writeVideo:0 outputPTS:videoOutputPTS]);

    int64_t targetAudioOutputPTS =
        videoOutputPTS * info1->sampleRate / info0->frameRate;
    for (int64_t audioOutputPTS = nextAudioOutputPTS;
         audioOutputPTS < targetAudioOutputPTS;
         audioOutputPTS += audioNumSamples) {
      XCTAssertTrue([writer makeFrameWritable:1]);
      AudioFrame frame;
      frame.numSamples = audioNumSamples;
      frame.data = [writer getBaseAddress:1 ofPlane:0];

      [self fillDummyAudioFrame:&frame];

      XCTAssertTrue([writer writeAudio:1 outputPTS:audioOutputPTS]);

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

- (void)testSparseAudio {
  VideoInfo *info0 = &screenVideoInfo0;
  AudioInfo *info1 = &screenAudioInfo;

  [self setUpDummyVideo];
  [self setUpDummyAudio:info1];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testSparseAudio.mkv"];

  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:info0->width
                                height:info0->height
                             frameRate:info0->frameRate
                               bitRate:info0->bitRate]);
  XCTAssertTrue([writer addAudioStream:1
                            sampleRate:info1->sampleRate
                               bitRate:info1->bitRate]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer openAudio:1]);
  XCTAssertTrue([writer startOutput]);

  int64_t nextAudioOutputPTS = 0;
  int64_t audioNumSamples = [writer getNumSamples:1];
  for (int64_t videoOutputPTS = 0; videoOutputPTS < 60; videoOutputPTS++) {
    XCTAssertTrue([writer makeFrameWritable:0]);
    VideoFrame frame;
    frame.width = [writer getWidth:0];
    frame.height = [writer getHeight:0];
    frame.lumaData = [writer getBaseAddress:0 ofPlane:0];
    frame.chromaData = [writer getBaseAddress:0 ofPlane:1];
    frame.lumaBytesPerRow = [writer getBytesPerRow:0 ofPlane:0];
    frame.chromaBytesPerRow = [writer getBytesPerRow:0 ofPlane:1];

    [self fillDummyVideoFrame:&frame];

    XCTAssertTrue([writer writeVideo:0 outputPTS:videoOutputPTS]);

    int64_t targetAudioOutputPTS =
        videoOutputPTS * info1->sampleRate / info0->frameRate;
    for (int64_t audioOutputPTS = nextAudioOutputPTS;
         audioOutputPTS < targetAudioOutputPTS;
         audioOutputPTS += audioNumSamples) {
      XCTAssertTrue([writer makeFrameWritable:1]);
      AudioFrame frame;
      frame.numSamples = audioNumSamples;
      frame.data = [writer getBaseAddress:1 ofPlane:0];

      if ((audioOutputPTS / audioNumSamples) % 2 == 0) {
        [self fillDummyAudioFrame:&frame];
        XCTAssertTrue([writer writeAudio:1 outputPTS:audioOutputPTS]);
      }

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

- (void)testAudioWithResampling {
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

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testAudioWithResampling.mp4"];

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
        .data = data,
    };
    [self fillDummyAudioFrame:&frame];
    int64_t outputPTS =
        i * frame.numSamples * info0dst.sampleRate / info0src.sampleRate;
    XCTAssertTrue([writer ensureResamplerIsInitialted:0
                                           sampleRate:info0src.sampleRate
                                          numChannels:info0src.numChannels]);
    XCTAssertTrue([writer writeAudioWithResampling:0
                                         outputPTS:outputPTS
                                            inData:(uint8_t *)frame.data
                                           inCount:(int)frame.numSamples]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testSparseAudioWithResampling {
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

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testSparseAudioWithResampling.mp4"];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0dst.sampleRate
                               bitRate:info0dst.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  int16_t data[2048];
  for (int i = 0; i < 43; i++) {
    AudioFrame frame = {
        .numSamples = 1024,
        .data = data,
    };
    [self fillDummyAudioFrame:&frame];
    if (i % 2 == 1) {
      continue;
    }
    int64_t outputPTS =
        i * frame.numSamples * info0dst.sampleRate / info0src.sampleRate;
    XCTAssertTrue([writer ensureResamplerIsInitialted:0
                                           sampleRate:info0src.sampleRate
                                          numChannels:info0src.numChannels]);
    XCTAssertTrue([writer writeAudioWithResampling:0
                                         outputPTS:outputPTS
                                            inData:(uint8_t *)frame.data
                                           inCount:(int)frame.numSamples]);
    XCTAssertTrue([writer flushAudioWithResampling:0]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}

- (void)testVideoAndEmptyAudio {
  VideoInfo info0 = {
      .width = 888,
      .height = 1920,
      .frameRate = 60,
      .bitRate = 8000000,
  };
  AudioInfo info1 = {
      .sampleRate = 48000,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyVideo];
  [self setUpDummyAudio:&info1];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testVideoAndSparseAudio.mkv"];

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
  XCTAssertTrue([writer ensureResamplerIsInitialted:1
                                         sampleRate:info1.sampleRate
                                        numChannels:info1.numChannels]);

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

    XCTAssertTrue([writer flushAudioWithResampling:1]);
  }

  [writer finishStream:0];
  [writer finishStream:1];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeStream:1];
  [writer closeOutput];
}

- (void)testSwappedAudio {
  AudioInfo info0 = {
      .sampleRate = 48000,
      .bitRate = 320000,
      .numChannels = 2,
  };

  [self setUpDummyAudio:&info0];

  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];

  NSString *path = [self getOutputPath:@"testSwappedAudio.mp4"];

  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  XCTAssertTrue([writer openOutputFile:path]);
  XCTAssertTrue([writer addAudioStream:0
                            sampleRate:info0.sampleRate
                               bitRate:info0.bitRate]);
  XCTAssertTrue([writer openAudio:0]);
  XCTAssertTrue([writer startOutput]);

  for (int i = 0; i < 43; i++) {
    XCTAssertTrue([writer makeFrameWritable:0]);
    AudioFrame frame = {
      .numSamples = [writer getNumSamples:0],
      .data = [writer getBaseAddress:0 ofPlane:0],
    };

    [self fillDummyAudioFrame:&frame];

    uint8_t *dataView = (uint8_t *)frame.data;
    for (int i = 0; i < frame.numSamples; i++) {
      uint8_t tmp = dataView[i * 2];
      dataView[i * 2] = dataView[i * 2 + 1];
      dataView[i * 2 + 1] = tmp;
    }

    [writer swapInt16Bytes:(uint16_t *)frame.data from:(uint16_t *)frame.data numBytes:frame.numSamples * info0.numChannels];

    XCTAssertTrue([writer writeAudio:0 outputPTS:i * frame.numSamples]);
  }

  [writer finishStream:0];
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeOutput];
}
@end
