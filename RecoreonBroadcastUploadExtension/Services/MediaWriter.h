#pragma once

#import <CoreMedia/CoreMedia.h>

#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

typedef struct OutputStream {
  AVStream *st;
  AVCodecContext *enc;
  AVFrame *frame;
  AVPacket *tmp_pkt;
} OutputStream;

@interface MediaWriter : NSObject {
  NSString * __nonnull filename;
  AVFormatContext *outputFormatContext;
  const AVCodec *videoCodec;
  const AVCodec *audioCodec;

  OutputStream screenVideoStream;
  OutputStream screenAudioStream;
  OutputStream micAudioStream;

  BOOL firstScreenVideoFrameReceived;
  int64_t screenBasePts;
  int64_t micBasePts;
}
- (void)open:(NSString * __nonnull)filename;
- (void)writeVideoOfScreen:(CMSampleBufferRef __nonnull)sampleBuffer
               pixelBuffer:(CVPixelBufferRef __nonnull)pixelBuffer;
- (void)writeAudioOfScreen:(CMSampleBufferRef __nonnull)sampleBuffer
           audioBufferList:(AudioBufferList * __nonnull)audioBufferList;
- (void)writeAudioOfMic:(CMSampleBufferRef __nonnull)sampleBuffer
        audioBufferList:(AudioBufferList * __nonnull)audioBufferList;
- (void)close;
@end
