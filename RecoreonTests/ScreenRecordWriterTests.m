//
//  RecordWriterTests.m
//  RecoreonTests
//
//  Created by Kaito Udagawa on 2023/11/13.
//

#import <XCTest/XCTest.h>

#import "../RecoreonBroadcastUploadExtension/ScreenRecordWriter.h"

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

- (void)testAddVideoStream {
  ScreenRecordWriter *writer = [[ScreenRecordWriter alloc] init];
  XCTAssertTrue([writer openVideoCodec:@"h264_videotoolbox"]);
  XCTAssertTrue([writer openAudioCodec:@"aac_at"]);
  NSString *filename = @"test.mkv";
  XCTAssertTrue([writer openOutputFile:filename]);
  XCTAssertTrue([writer addVideoStream:0
                                 width:888
                                height:1920
                             frameRate:120
                               bitRate:8000000]);
  XCTAssertTrue([writer addAudioStream:1 sampleRate:44100 bitRate:320000]);
  XCTAssertTrue([writer addAudioStream:2 sampleRate:48000 bitRate:320000]);
  XCTAssertTrue([writer openVideo:0]);
  XCTAssertTrue([writer openAudio:1]);
  XCTAssertTrue([writer openAudio:2]);
  [writer finishOutput];
  [writer closeStream:0];
  [writer closeStream:1];
  [writer closeStream:2];
  [writer closeOutput];
}

//- (void)testPerformanceExample {
//  // This is an example of a performance test case.
//  [self measureBlock:^{
//      // Put the code you want to measure the time of here.
//  }];
//}

@end
