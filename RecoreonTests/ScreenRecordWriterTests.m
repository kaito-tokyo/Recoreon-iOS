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

@end
