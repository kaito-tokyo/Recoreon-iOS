#include <libavutil/avassert.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libavutil/mathematics.h>
#include <libavutil/timestamp.h>

#define STREAM_FRAME_RATE 120 /* 25 images/s */
#define STREAM_PIX_FMT    AV_PIX_FMT_NV12 /* default pix_fmt */

#import "Matroska.h"

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt)
{
//    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;
//
//    printf("pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
//           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
//           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
//           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
//           pkt->stream_index);
}

static int write_frame(AVFormatContext *fmt_ctx, AVCodecContext *c,
                       AVStream *st, AVFrame *frame, AVPacket *pkt)
{
    int ret;

    // send the frame to the encoder
    ret = avcodec_send_frame(c, frame);
    if (ret < 0) {
        NSLog(@"Error sending a frame to the encoder: %s", av_err2str(ret));
        return ret;
    }

    while (ret >= 0) {
        ret = avcodec_receive_packet(c, pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
            break;
        else if (ret < 0) {
            NSLog(@"Error encoding a frame: %s", av_err2str(ret));
            return ret;
        }

        /* rescale output packet timestamp values from codec to stream timebase */
        av_packet_rescale_ts(pkt, c->time_base, st->time_base);
        pkt->stream_index = st->index;

        /* Write the compressed frame to the media file. */
        log_packet(fmt_ctx, pkt);
        ret = av_interleaved_write_frame(fmt_ctx, pkt);
        /* pkt is now blank (av_interleaved_write_frame() takes ownership of
         * its contents and resets pkt), so that no unreferencing is necessary.
         * This would be different if one used av_write_frame(). */
        if (ret < 0) {
            NSLog(@"Error while writing output packet: %s", av_err2str(ret));
            return ret;
        }
    }

    return ret == AVERROR_EOF ? 1 : 0;
}

/**************************************************************/
/* audio output */

static AVFrame *alloc_audio_frame(enum AVSampleFormat sample_fmt,
                                  const AVChannelLayout *channel_layout,
                                  int sample_rate, int nb_samples)
{
    AVFrame *frame = av_frame_alloc();
    if (!frame) {
        NSException *e = [NSException exceptionWithName:@"AudioFrameNotAllocatedException" reason:@"Error allocating an audio frame!" userInfo:nil];
        @throw e;
    }

    frame->format = sample_fmt;
    av_channel_layout_copy(&frame->ch_layout, channel_layout);
    frame->sample_rate = sample_rate;
    frame->nb_samples = nb_samples;

    if (nb_samples) {
        if (av_frame_get_buffer(frame, 0) < 0) {
            NSException *e = [NSException exceptionWithName:@"AudioBufferNotAllocatedException" reason:@"Error allocating an audio buffer!" userInfo:nil];
            @throw e;
        }
    }

    return frame;
}

static void open_audio(AVFormatContext *oc, const AVCodec *codec,
                       OutputStream *ost, AVDictionary *opt_arg)
{
    AVCodecContext *c;
    int nb_samples;
    int ret;
    AVDictionary *opt = NULL;

    c = ost->enc;

    /* open it */
    av_dict_copy(&opt, opt_arg, 0);
    ret = avcodec_open2(c, codec, &opt);
    av_dict_free(&opt);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"AudioCodecNotOpenedException" reason:@"Could not open audio codec!" userInfo:@{
            @"String" : [NSString stringWithUTF8String:av_err2str(ret)]
        }];
        @throw e;
    }

    if (c->codec->capabilities & AV_CODEC_CAP_VARIABLE_FRAME_SIZE)
        nb_samples = 10000;
    else
        nb_samples = c->frame_size;

    ost->frame     = alloc_audio_frame(AV_SAMPLE_FMT_FLTP, &c->ch_layout,
                                       c->sample_rate, nb_samples);

    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"StreamParameterNotCopiedException" reason:@"Could not copy the stream parameters!" userInfo:nil];
        @throw e;
    }
}

/**************************************************************/
/* video output */

static AVFrame *alloc_frame(enum AVPixelFormat pix_fmt, int width, int height)
{
    AVFrame *frame;
    int ret;

    frame = av_frame_alloc();
    if (!frame)
        return NULL;

    frame->format = pix_fmt;
    frame->width  = width;
    frame->height = height;
    frame->color_range = AVCOL_RANGE_JPEG;

    /* allocate the buffers for the frame data */
    ret = av_frame_get_buffer(frame, 0);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"FrameDataNotAllocatedException" reason:@"Could not allocate frame data!" userInfo:nil];
        @throw e;
    }

    return frame;
}

static void open_video(AVFormatContext *oc, const AVCodec *codec,
                       OutputStream *ost, AVDictionary *opt_arg)
{
    int ret;
    AVCodecContext *c = ost->enc;
    AVDictionary *opt = NULL;

    av_dict_copy(&opt, opt_arg, 0);

    /* open the codec */
    ret = avcodec_open2(c, codec, &opt);
    av_dict_free(&opt);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"VideoCodecNotOpenedException" reason:@"Could not open video codec!" userInfo:@{
            @"String" : [NSString stringWithUTF8String:av_err2str(ret)]
        }];
        @throw e;
    }

    /* allocate and init a re-usable frame */
    ost->frame = alloc_frame(c->pix_fmt, c->width, c->height);
    if (!ost->frame) {
        NSException *e = [NSException exceptionWithName:@"VideoFrameNotAllocatedException" reason:@"Could not allocate video frame!" userInfo:nil];
        @throw e;
    }

    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"StreamParameterNotCopiedException" reason:@"Could not copy the stream parameters!" userInfo:nil];
        @throw e;
    }
}

static void copyPlane(uint8_t *dst, size_t dstLinesize, uint8_t *src, size_t srcLinesize, size_t width, size_t height) {
    assert(width <= dstLinesize);
    assert(width <= srcLinesize);

    if (dstLinesize == srcLinesize) {
        memcpy(dst, src, dstLinesize * height);
    } else {
        for (int i = 0; i < height; i++) {
            memcpy(&dst[dstLinesize * i], &src[srcLinesize * i], width);
        }
    }
}

static void close_stream(AVFormatContext *oc, OutputStream *ost)
{
    avcodec_free_context(&ost->enc);
    av_frame_free(&ost->frame);
    av_packet_free(&ost->tmp_pkt);
}

@implementation Matroska : NSObject
- (void)open:(NSString *)_filename {
    filename = _filename;

    avformat_alloc_output_context2(&outputFormatContext, NULL, NULL, [filename UTF8String]);
    if (!outputFormatContext) {
        NSException *e = [NSException exceptionWithName:@"AVFormatContextNotAllocatedException" reason:@"Could not allocate AVFormatContext!" userInfo:nil];
        @throw e;
    }
    
    const char *videoCodecName = "h264_videotoolbox";
    videoCodec = avcodec_find_encoder_by_name(videoCodecName);
    if (!videoCodec) {
        NSException *e = [NSException exceptionWithName:@"VideoCodecNotFoundException" reason:@"Could not find the video codec!" userInfo:@{
            @"EncoderName": [NSString stringWithUTF8String:videoCodecName]
        }];
        @throw e;
    }
    
    const char *audioCodecName = "aac_at";
    audioCodec = avcodec_find_encoder_by_name(audioCodecName);
    if (!audioCodec) {
        NSException *e = [NSException exceptionWithName:@"AudioCodecNotFoundException" reason:@"Could not find the audio codec!" userInfo:@{
            @"EncoderName": [NSString stringWithUTF8String:audioCodecName]
        }];
        @throw e;
    }
}
- (void)onFirstVideoFrame:(CMSampleBufferRef)sampleBuffer pixelBuffer:(CVPixelBufferRef)pixelBuffer {
    int ret;

    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int height = (int)CVPixelBufferGetHeight(pixelBuffer);
    [self addVideoStream:&videoStreamScreen index:0 width:width height:height];
    [self addAudioStream:&audioStreamScreen index:1];

    open_video(outputFormatContext, videoCodec, &videoStreamScreen, NULL);
    open_audio(outputFormatContext, audioCodec, &audioStreamScreen, NULL);

    av_dump_format(outputFormatContext, 0, [filename UTF8String], 1);
    
    ret = avio_open(&outputFormatContext->pb, [filename UTF8String], AVIO_FLAG_WRITE);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"FileNotOpenedException" reason:@"Could not open!" userInfo:@{
            @"String" : [NSString stringWithUTF8String:av_err2str(ret)]
        }];
        @throw e;
    }

    ret = avformat_write_header(outputFormatContext, NULL);
    if (ret < 0) {
        NSException *e = [NSException exceptionWithName:@"FileNotOpenedException" reason:@"Error occurred when opening output file!" userInfo:@{
            @"String" : [NSString stringWithUTF8String:av_err2str(ret)]
        }];
        @throw e;
    }
}
- (void)addVideoStream:(struct OutputStream *)outputStream index:(int)index width:(int)width height:(int)height {
    outputStream->tmp_pkt = av_packet_alloc();
    if (!outputStream->tmp_pkt) {
        NSException *e = [NSException exceptionWithName:@"AVPacketNotAllocatedException" reason:@"Could not allocate AVPacket!" userInfo:nil];
        @throw e;
    }

    AVStream *stream = avformat_new_stream(outputFormatContext, NULL);
    if (!stream) {
        NSException *e = [NSException exceptionWithName:@"StreamNotAllocatedException" reason:@"Could not allocate stream!" userInfo:nil];
        @throw e;
    }
    stream->id = index;
    outputStream->st = stream;
    
    AVCodecContext *codecContext = avcodec_alloc_context3(videoCodec);
    if (!codecContext) {
        NSException *e = [NSException exceptionWithName:@"CodecContextNotAllocatedException" reason:@"Could not allocate an encoding context!" userInfo:nil];
        @throw e;
    }
    outputStream->enc = codecContext;

    codecContext->codec_id = AV_CODEC_ID_H264;
    codecContext->bit_rate = 8000000;
    codecContext->width = width;
    codecContext->height = height;
    codecContext->time_base = stream->time_base = (AVRational){ 1, STREAM_FRAME_RATE };
    codecContext->gop_size = 12;
    codecContext->pix_fmt = STREAM_PIX_FMT;
    codecContext->color_range = AVCOL_RANGE_JPEG;
    codecContext->color_primaries = AVCOL_PRI_BT709;

    if (outputFormatContext->oformat->flags & AVFMT_GLOBALHEADER) {
        codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
}
- (void)addAudioStream:(struct OutputStream *)outputStream index:(int)index {
    outputStream->tmp_pkt = av_packet_alloc();
    if (!outputStream->tmp_pkt) {
        NSException *e = [NSException exceptionWithName:@"AVPacketNotAllocatedException" reason:@"Could not allocate AVPacket!" userInfo:nil];
        @throw e;
    }

    AVStream *stream = avformat_new_stream(outputFormatContext, NULL);
    if (!stream) {
        NSException *e = [NSException exceptionWithName:@"StreamNotAllocatedException" reason:@"Could not allocate stream!" userInfo:nil];
        @throw e;
    }
    stream->id = index;
    outputStream->st = stream;
    
    AVCodecContext *codecContext = avcodec_alloc_context3(audioCodec);
    if (!codecContext) {
        NSException *e = [NSException exceptionWithName:@"CodecContextNotAllocatedException" reason:@"Could not allocate an encoding context!" userInfo:nil];
        @throw e;
    }
    outputStream->enc = codecContext;

    codecContext->sample_fmt = AV_SAMPLE_FMT_U8;
    codecContext->bit_rate = 320000;
    codecContext->sample_rate = 44100;
    AVChannelLayout layout = AV_CHANNEL_LAYOUT_STEREO;
    av_channel_layout_copy(&codecContext->ch_layout, &layout);
    codecContext->time_base = stream->time_base = (AVRational){ 1, codecContext->sample_rate };

    if (outputFormatContext->oformat->flags & AVFMT_GLOBALHEADER) {
        codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
}
- (void)writeVideo:(CMSampleBufferRef)sampleBuffer pixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!firstVideoFrameReceived) {
        [self onFirstVideoFrame:sampleBuffer pixelBuffer:pixelBuffer];
        firstVideoFrameReceived = true;
    }

    AVFrame *frame = videoStreamScreen.frame;
    if (av_frame_make_writable(frame) < 0) {
        NSLog(@"Could not make a frame writable!");
        return;
    }
    
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    if (pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        NSLog(@"The pixel format is not supported!");
        return;
    }

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    if (width != 888) {
        NSLog(@"The width of video is not 888!");
        return;
    }
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    if (height != 1920) {
        NSLog(@"The width of video is not 1920!");
        return;
    }

    size_t yLinesize = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
    size_t cbcrLinesize = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    uint8_t *yPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    uint8_t *cbcrPlane = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    copyPlane((uint8_t *)frame->data[0], frame->linesize[0], yPlane, yLinesize, width, height);
    copyPlane((uint8_t *)frame->data[1], frame->linesize[1], cbcrPlane, cbcrLinesize, width, height / 2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (!basePtsInitialized) {
        basePts = pts.value;
        basePtsInitialized = true;
    }
    videoStreamScreen.frame->pts = (pts.value - basePts) * STREAM_FRAME_RATE / pts.timescale;

    write_frame(outputFormatContext, videoStreamScreen.enc, videoStreamScreen.st, videoStreamScreen.frame, videoStreamScreen.tmp_pkt);
}
- (void)writeAudio:(CMSampleBufferRef)sampleBuffer audioBufferList:(AudioBufferList *)audioBufferList {
    if (!firstVideoFrameReceived) {
        return;
    }

    AVFrame *frame = audioStreamScreen.frame;
    if (av_frame_make_writable(frame) < 0) {
        NSLog(@"Could not make a frame writable!");
        return;
    }

    CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
    if (fmt == NULL) {
        NSLog(@"Could not get the format description!");
        return;
    }
    
    const AudioStreamBasicDescription *desc = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
    if (desc == NULL) {
        NSLog(@"Could not get the audio stream basic description!");
        return;
    }
    
    if (desc->mFormatID != kAudioFormatLinearPCM) {
        NSLog(@"The format is not supported!");
        return;
    }
    
    if (desc->mSampleRate != 44100) {
        NSLog(@"The sample rate is not supported!");
        return;
    }
    
    if (desc->mBitsPerChannel != 16) {
        NSLog(@"The bits per channel is not supported!");
        return;
    }
    
    if (desc->mChannelsPerFrame != 2) {
        NSLog(@"The channels per frame is not supported!");
        return;
    }
    
    if (!(desc->mFormatFlags & kAudioFormatFlagIsBigEndian)) {
        NSLog(@"The sample format is not big endian!");
        return;
    }

    if (audioBufferList->mNumberBuffers != 1) {
        NSLog(@"The audio buffer is not interleaved!");
        return;
    }
    
    if (audioBufferList->mBuffers[0].mDataByteSize != 4096) {
        NSLog(@"The size of the audio buffer is %u and not 4096!", audioBufferList->mBuffers[0].mDataByteSize);
        return;
    }

    OutputStream *ost = &audioStreamScreen;
    AVCodecContext *c;

    c = ost->enc;

    uint16_t *buf = (uint16_t *)audioBufferList->mBuffers[0].mData;
    uint8_t *data = (uint8_t *)frame->data[0];
    for (int i = 0; i < 2048; i++) {
        uint16_t unsigned16Value = buf[i] >> 8 | buf[i] << 8;
        uint8_t unsined8Value = (int32_t)*(int16_t *)&unsigned16Value * 127 / 32768 + 127;
        data[i] = unsined8Value;
    }
    
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (!basePtsInitialized) {
        basePts = pts.value;
        basePtsInitialized = true;
    }
    frame->pts = (pts.value - basePts) * 44100.0 / pts.timescale;

    write_frame(outputFormatContext, c, ost->st, frame, ost->tmp_pkt);
}
- (void)close {
    av_write_trailer(outputFormatContext);

    close_stream(outputFormatContext, &videoStreamScreen);
    close_stream(outputFormatContext, &audioStreamScreen);
    avio_closep(&outputFormatContext->pb);
    avformat_free_context(outputFormatContext);
}
@end
