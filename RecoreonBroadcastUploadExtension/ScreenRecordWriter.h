#pragma once

#import <CoreMedia/CoreMedia.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

typedef struct OutputStream {
  AVStream *__nullable stream;
  AVCodecContext *__nullable codecContext;
  AVFrame *__nullable frame;
  AVPacket *__nullable packet;
  int64_t basePts;
} OutputStream;

@interface ScreenRecordWriter : NSObject {
  const AVCodec *__nullable videoCodec;
  const AVCodec *__nullable audioCodec;
  AVFormatContext *__nullable formatContext;
  OutputStream outputStreams[3];
  BOOL isFirstScreenVideoFrameReceived;
}

@property(nonatomic, readonly) NSString *__nullable filename;

- (BOOL)openVideoCodec:(NSString *__nonnull)name;
- (BOOL)openAudioCodec:(NSString *__nonnull)name;
- (BOOL)openOutputFile:(NSString *__nonnull)filename;
- (BOOL)addVideoStream:(int)index
                 width:(int)width
                height:(int)height
             frameRate:(int)frameRate
               bitRate:(int)bitRate;
- (BOOL)addAudioStream:(int)index
            sampleRate:(int)sampleRate
               bitRate:(int)bitRate;
- (BOOL)openVideo:(int)index;
- (BOOL)openAudio:(int)index;
- (void)finishOutput;
- (void)closeStream:(int)index;
- (void)closeOutput;
@end