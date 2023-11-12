#pragma once

#import <CoreMedia/CoreMedia.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

#import "InputAudioSampleReader.h"

typedef struct OutputStream {
  AVStream *__nullable st;
  AVCodecContext *__nullable enc;
  AVFrame *__nullable frame;
  AVPacket *__nullable tmp_pkt;
} OutputStream;

@interface MediaWriter : NSObject {
  NSString *__nullable filename;
  AVFormatContext *outputFormatContext;
  const AVCodec *videoCodec;
  const AVCodec *audioCodec;

  OutputStream screenVideoStream;
  OutputStream screenAudioStream;
  OutputStream micAudioStream;

  BOOL firstScreenVideoFrameReceived;
  int64_t screenBasePts;
  int64_t micBasePts;

  InputAudioSampleReader *screenInputAudioSampleReader;
  InputAudioSampleReader *micInputAudioSampleReader;
}

@property(nonatomic) size_t desiredLumaBytesPerRow;
@property(nonatomic) size_t desiredChromaBytesPerRow;

- (void)open:(NSString *__nonnull)filename;
- (void)writeVideoOfScreen:(CMSampleBufferRef __nonnull)sampleBuffer
               pixelBuffer:(CVPixelBufferRef __nonnull)pixelBuffer
                  lumaData:(void *__nonnull)lumaData
                chromaData:(void *__nonnull)chromaData
           lumaBytesPerRow:(long)lumaBytesPerRow
         chromaBytesPerRow:(long)chromaBytesPerRow;
- (void)writeAudioOfScreen:(CMSampleBufferRef __nonnull)sampleBuffer
           audioBufferList:(AudioBufferList *__nonnull)audioBufferList;
- (void)writeAudioOfMic:(CMSampleBufferRef __nonnull)sampleBuffer
        audioBufferList:(AudioBufferList *__nonnull)audioBufferList;
- (void)close;
@end
