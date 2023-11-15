#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

#define MAX_STREAMS 8

typedef struct OutputStream {
  AVStream *__nullable stream;
  AVCodecContext *__nullable codecContext;
  AVFrame *__nullable frame;
  AVPacket *__nullable packet;

  AudioStreamBasicDescription inputASBD;
  AudioStreamBasicDescription outputASBD;
  AudioConverterRef __nullable audioConverter;
} OutputStream;

@interface ScreenRecordWriter : NSObject {
  const AVCodec *__nullable videoCodec;
  const AVCodec *__nullable audioCodec;
  AVFormatContext *__nullable formatContext;
  OutputStream outputStreams[MAX_STREAMS];

@public
  int16_t buf[2048];
@public
  AudioBufferList *__nullable abl;
}

@property(nonatomic, readonly) NSString *__nullable filename;

- (bool)openVideoCodec:(NSString *__nonnull)name;
- (bool)openAudioCodec:(NSString *__nonnull)name;
- (bool)openOutputFile:(NSString *__nonnull)filename;
- (bool)addVideoStream:(long)index
                 width:(long)width
                height:(long)height
             frameRate:(long)frameRate
               bitRate:(long)bitRate;
- (bool)addAudioStream:(long)index
            sampleRate:(long)sampleRate
               bitRate:(long)bitRate;
- (bool)openVideo:(long)index;
- (bool)openAudio:(long)index;
- (bool)startOutput;
- (bool)makeFrameWritable:(long)index;
- (long)getWidth:(long)index;
- (long)getHeight:(long)index;
- (long)getBytesPerRow:(long)index ofPlane:(long)planeIndex;
- (long)getNumSamples:(long)index;
- (void *__nonnull)getBaseAddress:(long)index ofPlane:(long)planeIndex;
- (bool)writeFrame:(long)index;
- (bool)writeVideo:(long)index outputPTS:(int64_t)outputPTS;
- (bool)writeAudio:(long)index outputPTS:(int64_t)outputPTS;
- (void)finishStream:(long)index;
- (void)finishOutput;
- (void)closeStream:(long)index;
- (void)closeOutput;
@end
