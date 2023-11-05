#include <string>

extern "C" {
#include <libavutil/avassert.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libavutil/mathematics.h>
#include <libavutil/timestamp.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
}

#define STREAM_DURATION   10.0
#define STREAM_FRAME_RATE 60 /* 25 images/s */
#define STREAM_PIX_FMT    AV_PIX_FMT_NV12 /* default pix_fmt */

#define SCALE_FLAGS SWS_BICUBIC

#import "Matroska.h"

typedef struct OutputStream {
    AVStream *st;
    AVCodecContext *enc;

    /* pts of the next frame that will be generated */
    int64_t next_pts;
    int64_t pts_base;
    int samples_count;

    AVFrame *frame;

    AVPacket *tmp_pkt;

    float t, tincr, tincr2;

    struct SwsContext *sws_ctx;
    struct SwrContext *swr_ctx;
} OutputStream;

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt)
{
    AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;

    printf("pts:%s pts_time:%s dts:%s dts_time:%s duration:%s duration_time:%s stream_index:%d\n",
           av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
           av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
           av_ts2str(pkt->duration), av_ts2timestr(pkt->duration, time_base),
           pkt->stream_index);
}

static int write_frame(AVFormatContext *fmt_ctx, AVCodecContext *c,
                       AVStream *st, AVFrame *frame, AVPacket *pkt)
{
    int ret;

    // send the frame to the encoder
    ret = avcodec_send_frame(c, frame);
    if (ret < 0) {
        fprintf(stderr, "Error sending a frame to the encoder: %s\n",
                av_err2str(ret));
        throw "a";
    }

    while (ret >= 0) {
        ret = avcodec_receive_packet(c, pkt);
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
            break;
        else if (ret < 0) {
            fprintf(stderr, "Error encoding a frame: %s\n", av_err2str(ret));
            throw "a";
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
            fprintf(stderr, "Error while writing output packet: %s\n", av_err2str(ret));
            throw "a";
        }
    }

    return ret == AVERROR_EOF ? 1 : 0;
}

/* Add an output stream. */
static void add_stream(OutputStream *ost, AVFormatContext *oc,
                       const AVCodec **codec,
                       enum AVCodecID codec_id,
                       const char *codec_name)
{
    AVCodecContext *c;
    int i;

    /* find the encoder */
    if (codec_name == NULL) {
        *codec = avcodec_find_encoder(codec_id);
    } else {
        *codec = avcodec_find_encoder_by_name(codec_name);
    }
    if (!(*codec)) {
        fprintf(stderr, "Could not find encoder for '%s'\n",
                avcodec_get_name(codec_id));
        throw "a";
    }

    ost->tmp_pkt = av_packet_alloc();
    if (!ost->tmp_pkt) {
        fprintf(stderr, "Could not allocate AVPacket\n");
        throw "a";
    }

    ost->st = avformat_new_stream(oc, NULL);
    if (!ost->st) {
        fprintf(stderr, "Could not allocate stream\n");
        throw "a";
    }
    ost->st->id = oc->nb_streams-1;
    c = avcodec_alloc_context3(*codec);
    if (!c) {
        fprintf(stderr, "Could not alloc an encoding context\n");
        throw "a";
    }
    ost->enc = c;
    
    AVChannelLayout layout = AV_CHANNEL_LAYOUT_STEREO;
    switch ((*codec)->type) {
    case AVMEDIA_TYPE_AUDIO:
            NSLog(@"%d", );
        c->sample_fmt  = AV_SAMPLE_FMT_FLTP;
        c->bit_rate    = 64000;
        c->sample_rate = 44100;
        if ((*codec)->supported_samplerates) {
            c->sample_rate = (*codec)->supported_samplerates[0];
            for (i = 0; (*codec)->supported_samplerates[i]; i++) {
                if ((*codec)->supported_samplerates[i] == 44100)
                    c->sample_rate = 44100;
            }
        }
        av_channel_layout_copy(&c->ch_layout, &layout);
        ost->st->time_base = (AVRational){ 1, c->sample_rate };
        break;

    case AVMEDIA_TYPE_VIDEO:
        c->codec_id = codec_id;

        c->bit_rate = 400000;
        /* Resolution must be a multiple of two. */
        c->width    = 888;
        c->height   = 1920;
        /* timebase: This is the fundamental unit of time (in seconds) in terms
         * of which frame timestamps are represented. For fixed-fps content,
         * timebase should be 1/framerate and timestamp increments should be
         * identical to 1. */
        ost->st->time_base = (AVRational){ 1, STREAM_FRAME_RATE };
        c->time_base       = ost->st->time_base;

        c->gop_size      = 12; /* emit one intra frame every twelve frames at most */
        c->pix_fmt       = STREAM_PIX_FMT;
        if (c->codec_id == AV_CODEC_ID_MPEG2VIDEO) {
            /* just for testing, we also add B-frames */
            c->max_b_frames = 2;
        }
        if (c->codec_id == AV_CODEC_ID_MPEG1VIDEO) {
            /* Needed to avoid using macroblocks in which some coeffs overflow.
             * This does not happen with normal video, it just happens here as
             * the motion of the chroma plane does not match the luma plane. */
            c->mb_decision = 2;
        }
        break;

    default:
        break;
    }

    /* Some formats want stream headers to be separate. */
    if (oc->oformat->flags & AVFMT_GLOBALHEADER)
        c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
}

/**************************************************************/
/* audio output */

static AVFrame *alloc_audio_frame(enum AVSampleFormat sample_fmt,
                                  const AVChannelLayout *channel_layout,
                                  int sample_rate, int nb_samples)
{
    AVFrame *frame = av_frame_alloc();
    if (!frame) {
        fprintf(stderr, "Error allocating an audio frame\n");
        throw "a";
    }

    frame->format = sample_fmt;
    av_channel_layout_copy(&frame->ch_layout, channel_layout);
    frame->sample_rate = sample_rate;
    frame->nb_samples = nb_samples;

    if (nb_samples) {
        if (av_frame_get_buffer(frame, 0) < 0) {
            fprintf(stderr, "Error allocating an audio buffer\n");
            throw "a";
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
        fprintf(stderr, "Could not open audio codec: %s\n", av_err2str(ret));
        throw "a";
    }

    /* init signal generator */
    ost->t     = 0;
    ost->tincr = 2 * M_PI * 110.0 / c->sample_rate;
    /* increment frequency by 110 Hz per second */
    ost->tincr2 = 2 * M_PI * 110.0 / c->sample_rate / c->sample_rate;

    if (c->codec->capabilities & AV_CODEC_CAP_VARIABLE_FRAME_SIZE)
        nb_samples = 10000;
    else
        nb_samples = c->frame_size;

    ost->frame     = alloc_audio_frame(AV_SAMPLE_FMT_FLTP, &c->ch_layout,
                                       c->sample_rate, nb_samples);

    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        throw "a";
    }

    /* create resampler context */
    ost->swr_ctx = swr_alloc();
    if (!ost->swr_ctx) {
        fprintf(stderr, "Could not allocate resampler context\n");
        throw "a";
    }

    /* set options */
    av_opt_set_chlayout  (ost->swr_ctx, "in_chlayout",       &c->ch_layout,      0);
    av_opt_set_int       (ost->swr_ctx, "in_sample_rate",     c->sample_rate,    0);
    av_opt_set_sample_fmt(ost->swr_ctx, "in_sample_fmt",      AV_SAMPLE_FMT_S16, 0);
    av_opt_set_chlayout  (ost->swr_ctx, "out_chlayout",      &c->ch_layout,      0);
    av_opt_set_int       (ost->swr_ctx, "out_sample_rate",    c->sample_rate,    0);
    av_opt_set_sample_fmt(ost->swr_ctx, "out_sample_fmt",     c->sample_fmt,     0);

    /* initialize the resampling context */
    if ((ret = swr_init(ost->swr_ctx)) < 0) {
        fprintf(stderr, "Failed to initialize the resampling context\n");
        throw "a";
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

    /* allocate the buffers for the frame data */
    ret = av_frame_get_buffer(frame, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not allocate frame data.\n");
        throw "a";
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
        fprintf(stderr, "Could not open video codec: %s\n", av_err2str(ret));
        throw "a";
    }

    /* allocate and init a re-usable frame */
    ost->frame = alloc_frame(c->pix_fmt, c->width, c->height);
    if (!ost->frame) {
        fprintf(stderr, "Could not allocate video frame\n");
        throw "a";
    }

    /* copy the stream parameters to the muxer */
    ret = avcodec_parameters_from_context(ost->st->codecpar, c);
    if (ret < 0) {
        fprintf(stderr, "Could not copy the stream parameters\n");
        throw "a";
    }
}

static void close_stream(AVFormatContext *oc, OutputStream *ost)
{
    avcodec_free_context(&ost->enc);
    av_frame_free(&ost->frame);
    av_packet_free(&ost->tmp_pkt);
    sws_freeContext(ost->sws_ctx);
    swr_free(&ost->swr_ctx);
}

OutputStream video_st = { 0 }, audio_st = { 0 };
const AVOutputFormat *fmt;

std::string filenamestring;
AVFormatContext *oc;
const AVCodec *audio_codec, *video_codec;
int ret;
int have_video = 0, have_audio = 0;
AVDictionary *opt = NULL;
int encode_video = 0, encode_audio = 0;
int i;

void copyPlane(uint8_t *dst, size_t dstLinesize, uint8_t *src, size_t srcLinesize, size_t width, size_t height) {
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

@implementation Matroska : NSObject
- (int)open:(NSString *)filename {
    std::string filenamestring = [filename UTF8String];

    /* allocate the output media context */
    avformat_alloc_output_context2(&oc, NULL, NULL, filenamestring.c_str());
    if (!oc) {
        printf("Could not deduce output format from file extension: using MPEG.\n");
        avformat_alloc_output_context2(&oc, NULL, "mpeg", filenamestring.c_str());
    }
    if (!oc)
        return 1;

    fmt = oc->oformat;

    /* Add the audio and video streams using the default format codecs
     * and initialize the codecs. */
    if (fmt->video_codec != AV_CODEC_ID_NONE) {
        add_stream(&video_st, oc, &video_codec, AV_CODEC_ID_NONE, "h264_videotoolbox");
        have_video = 1;
        encode_video = 1;
    }
    if (fmt->audio_codec != AV_CODEC_ID_NONE) {
        add_stream(&audio_st, oc, &audio_codec, AV_CODEC_ID_NONE, "aac_at");
        have_audio = 1;
        encode_audio = 1;
    }

    /* Now that all the parameters are set, we can open the audio and
     * video codecs and allocate the necessary encode buffers. */
    if (have_video)
        open_video(oc, video_codec, &video_st, opt);

    if (have_audio)
        open_audio(oc, audio_codec, &audio_st, opt);

    av_dump_format(oc, 0, filenamestring.c_str(), 1);

    /* open the output file, if needed */
    if (!(fmt->flags & AVFMT_NOFILE)) {
        ret = avio_open(&oc->pb, filenamestring.c_str(), AVIO_FLAG_WRITE);
        if (ret < 0) {
            fprintf(stderr, "Could not open '%s': %s\n", filenamestring.c_str(),
                    av_err2str(ret));
            return 1;
        }
    }

    /* Write the stream header, if any. */
    ret = avformat_write_header(oc, &opt);
    if (ret < 0) {
        fprintf(stderr, "Error occurred when opening output file: %s\n",
                av_err2str(ret));
        return 1;
    }
    
    return 0;
}
- (void)writeVideo:(CMSampleBufferRef)sampleBuffer {
    AVFrame *frame = video_st.frame;
    if (av_frame_make_writable(frame) < 0) {
        NSLog(@"Could not make a frame writable!");
        return;
    }

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer == NULL) {
        NSLog(@"Could not get a pixel buffer!");
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
    if (!baseSecondsInitialized) {
        baseSeconds = CMTimeGetSeconds(pts);
        baseSecondsInitialized = true;
    }
    video_st.frame->pts = (CMTimeGetSeconds(pts) - baseSeconds) * 60;
    NSLog(@"vpts: %lf %lld", CMTimeGetSeconds(pts) - baseSeconds);

    write_frame(oc, video_st.enc, video_st.st, video_st.frame, video_st.tmp_pkt);
    
    avio_flush(oc->pb);
}
- (void)writeAudio:(CMSampleBufferRef)sampleBuffer {
    AVFrame *frame = audio_st.frame;
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
    
    CMBlockBufferRef blockBuffer;
    AudioBufferList audioBufferList;
    
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, 0, &blockBuffer);
    
    if (audioBufferList.mNumberBuffers != 1) {
        NSLog(@"The audio buffer is not interleaved!");
        return;
    }
    
    if (audioBufferList.mBuffers[0].mDataByteSize != 4096) {
        NSLog(@"The size of the audio buffer is not 4096!");
        return;
    }

    OutputStream *ost = &audio_st;
    AVCodecContext *c;

    c = ost->enc;

    uint16_t *buf = (uint16_t *)audioBufferList.mBuffers[0].mData;
    float **data = (float **)frame->data;
    for (int i = 0; i < 1024; i++) {
        for (int j = 0; j < 2; j++) {
            uint16_t unsignedValue = buf[i * 2 + j] >> 8 | buf[i * 2 + j] << 8;
            float floatValue = *(int16_t *)&unsignedValue / 32768.0;
            data[j][i] = floatValue;
        }
    }
    
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (!baseSecondsInitialized) {
        baseSeconds = CMTimeGetSeconds(pts);
        baseSecondsInitialized = true;
    }
    frame->pts = (CMTimeGetSeconds(pts) - baseSeconds) * 44100.0;

    write_frame(oc, c, ost->st, frame, ost->tmp_pkt);
}
- (int)close {
    av_write_trailer(oc);

    /* Close each codec. */
    if (have_video)
        close_stream(oc, &video_st);
    if (have_audio)
        close_stream(oc, &audio_st);

    if (!(fmt->flags & AVFMT_NOFILE))
        /* Close the output file. */
        avio_closep(&oc->pb);

    /* free the stream */
    avformat_free_context(oc);
    
    return 0;
}
@end
