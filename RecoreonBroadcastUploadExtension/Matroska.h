#pragma once

#import <CoreMedia/CoreMedia.h>

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>

typedef struct OutputStream {
    AVStream *st;
    AVCodecContext *enc;
    AVFrame *frame;
    AVPacket *tmp_pkt;
} OutputStream;

@interface Matroska : NSObject {
    NSString *filename;
    AVFormatContext *outputFormatContext;
    const AVCodec *videoCodec;
    const AVCodec *audioCodec;
    
    struct OutputStream screenVideoStream;
    struct OutputStream screenAudioStream;
    struct OutputStream micAudioStream;
    
    BOOL firstScreenVideoFrameReceived;
    int64_t screenBasePts;
    int64_t micBasePts;
}
- (void)open:(NSString *)filename;
- (void)writeVideoOfScreen:(CMSampleBufferRef)sampleBuffer pixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)writeAudioOfScreen:(CMSampleBufferRef)sampleBuffer audioBufferList:(AudioBufferList *)audioBufferList;
- (void)writeAudioOfMic:(CMSampleBufferRef)sampleBuffer audioBufferList:(AudioBufferList *)audioBufferList;
- (void)close;
@end
