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
- (BOOL)startOutput;
- (int)getBytesPerRow:(int)index planeIndex:(int)planeIndex;
- (long)getByteCountOfAudioPlane:(long)index;
- (BOOL)checkIfVideoSampleIsValid:(CMSampleBufferRef __nonnull)sampleBuffer;
- (bool)prepareFrame:(long)index;
- (void *__nonnull)getBaseAddress:(long)index ofPlane:(long)planeIndex;
- (BOOL)writeVideo:(int)index
             lumaData:(void *__nonnull)lumaData
           chromaData:(void *__nonnull)chromaData
      lumaBytesPerRow:(long)lumaBytesPerRow
    chromaBytesPerRow:(long)chromaBytesPerRow
               height:(long)height
            outputPTS:(int64_t)outputPTS;
- (bool)
    ensureAudioConverterAvailable:(int)index
                             asbd:(const AudioStreamBasicDescription *__nonnull)
                                      asbd;
- (bool)writeAudio:(int)index outputPTS:(int64_t)outputPTS;
- (void)finishStream:(int)index;
- (void)finishOutput;
- (void)freeStream:(int)index;
- (void)freeOutput;
@end
