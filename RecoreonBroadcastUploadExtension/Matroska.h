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
    
    struct OutputStream videoStreamScreen;
    struct OutputStream audioStreamScreen;
    
    bool firstVideoFrameReceived;
    bool basePtsInitialized;
    double basePts;
}
- (void)open:(NSString *)filename;
- (void)writeVideo:(CMSampleBufferRef)sampleBuffer pixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)writeAudio:(CMSampleBufferRef)sampleBuffer audioBufferList:(AudioBufferList *)audioBufferList;
- (void)close;
@end
