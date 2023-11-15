#include <os/log.h>

#include <libavutil/timestamp.h>

#import "ScreenRecordWriter.h"

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt) {
#if DEBUG
  AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;

//  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,
//                   "pts:%s pts_time:%s dts:%s dts_time:%s duration:%s "
//                   "duration_time:%s stream_index:%d\n",
//                   av_ts2str(pkt->pts), av_ts2timestr(pkt->pts, time_base),
//                   av_ts2str(pkt->dts), av_ts2timestr(pkt->dts, time_base),
//                   av_ts2str(pkt->duration),
//                   av_ts2timestr(pkt->duration, time_base),
//                   pkt->stream_index);
#endif
}

static void copyPlane(uint8_t *dst, size_t dstLinesize, uint8_t *src,
                      size_t srcLinesize, size_t height) {
  if (dstLinesize == srcLinesize) {
    memcpy(dst, src, dstLinesize * height);
  } else {
    for (int i = 0; i < height; i++) {
      memcpy(&dst[dstLinesize * i], &src[srcLinesize * i],
             MIN(srcLinesize, dstLinesize));
    }
  }
}

@implementation ScreenRecordWriter
- (bool)openVideoCodec:(NSString *__nonnull)name {
  videoCodec = avcodec_find_encoder_by_name([name UTF8String]);
  if (videoCodec == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not find a video encoder: %@", name);
    return false;
  } else {
    return true;
  }
}

- (bool)openAudioCodec:(NSString *__nonnull)name {
  audioCodec = avcodec_find_encoder_by_name([name UTF8String]);
  if (audioCodec == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not find an audio encoder: %@", name);
    return false;
  } else {
    return true;
  }
}

- (BOOL)openOutputFile:(NSString *__nonnull)filename {
  _filename = filename;
  const char *path = [filename UTF8String];
  avformat_alloc_output_context2(&formatContext, NULL, NULL, path);
  if (formatContext == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not open an output file: %@", filename);
    return NO;
  } else {
    return YES;
  }
}

- (bool)addStream:(int)index {
  OutputStream *os = &outputStreams[index];

  os->packet = av_packet_alloc();
  if (!os->packet) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate a packet");
    return false;
  }

  AVStream *stream = avformat_new_stream(formatContext, NULL);
  if (!stream) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate a stream");
    return false;
  }
  stream->id = index;
  os->stream = stream;

  return true;
}

- (bool)addVideoStream:(int)index
                 width:(int)width
                height:(int)height
             frameRate:(int)frameRate
               bitRate:(int)bitRate {
  if (![self addStream:index]) {
    return false;
  }

  OutputStream *os = &outputStreams[index];

  AVCodecContext *c = avcodec_alloc_context3(videoCodec);
  if (!c) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate an video codec context");
    return false;
  }
  os->codecContext = c;

  c->codec_id = AV_CODEC_ID_H264;
  c->bit_rate = bitRate;
  c->width = width;
  c->height = height;
  AVRational timeBase = {1, frameRate};
  c->time_base = os->stream->time_base = timeBase;
  c->gop_size = 12;
  c->pix_fmt = AV_PIX_FMT_NV12;
  c->color_range = AVCOL_RANGE_JPEG;
  c->color_primaries = AVCOL_PRI_BT709;

  if (formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
    c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
  }

  return true;
}

- (bool)addAudioStream:(int)index
            sampleRate:(int)sampleRate
               bitRate:(int)bitRate {
  if (![self addStream:index]) {
    return false;
  }

  OutputStream *os = &outputStreams[index];

  AVCodecContext *c = avcodec_alloc_context3(audioCodec);
  if (!c) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate an video codec context");
    return false;
  }
  os->codecContext = c;

  c->sample_fmt = AV_SAMPLE_FMT_S16;
  c->bit_rate = bitRate;
  c->sample_rate = sampleRate;
  AVChannelLayout layout = AV_CHANNEL_LAYOUT_STEREO;
  av_channel_layout_copy(&c->ch_layout, &layout);
  AVRational timeBase = {1, sampleRate};
  c->time_base = os->stream->time_base = timeBase;

  if (formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
    c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
  }

  return true;
}

- (bool)openVideo:(int)index {
  OutputStream *os = &outputStreams[index];
  AVCodecContext *codecContext = os->codecContext;
  if (avcodec_open2(codecContext, videoCodec, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not open video codec context");
    return false;
  }

  AVFrame *frame = av_frame_alloc();
  if (frame == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate video frame");
    return false;
  }

  frame->format = codecContext->pix_fmt;
  frame->width = codecContext->width;
  frame->height = codecContext->height;
  frame->color_range = AVCOL_RANGE_JPEG;

  if (av_frame_get_buffer(frame, 0) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate video frame buffer");
    return false;
  }

  os->frame = frame;

  if (avcodec_parameters_from_context(os->stream->codecpar, codecContext) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not copy the video stream parameters");
    return false;
  }

  return true;
}

- (bool)openAudio:(int)index {
  OutputStream *os = &outputStreams[index];
  AVCodecContext *codecContext = os->codecContext;
  if (avcodec_open2(codecContext, audioCodec, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not open audio codec context");
    return false;
  }

  AVFrame *frame = av_frame_alloc();
  if (frame == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate audio frame");
    return false;
  }

  frame->format = codecContext->sample_fmt;
  av_channel_layout_copy(&frame->ch_layout, &codecContext->ch_layout);
  frame->sample_rate = codecContext->sample_rate;
  frame->nb_samples = codecContext->frame_size;

  if (av_frame_get_buffer(frame, 0) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate video frame buffer");
    return false;
  }

  os->frame = frame;

  if (avcodec_parameters_from_context(os->stream->codecpar, codecContext) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not copy the audio stream parameters");
    return false;
  }

  return true;
}

- (bool)startOutput {
  const char *path = [_filename UTF8String];
  av_dump_format(formatContext, 0, path, 1);

  if (avio_open(&formatContext->pb, path, AVIO_FLAG_WRITE) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not open the file io:%@", _filename);
    return false;
  }

  if (avformat_write_header(formatContext, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not write the header");
    return false;
  }

  return true;
}

- (int)getBytesPerRow:(int)index planeIndex:(int)planeIndex {
  return outputStreams[index].frame->linesize[planeIndex];
}

- (long)getByteCountOfAudioPlane:(long)index {
  return outputStreams[index].frame->nb_samples * 4;
}

- (bool)checkIfVideoSampleIsValid:(CMSampleBufferRef __nonnull)sampleBuffer {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixelBuffer == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not get the pixel buffer");
    return false;
  }

  OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  if (pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "The pixel format is not supported: %u", pixelFormat);
    return false;
  }

  return true;
}

- (bool)prepareFrame:(long)index {
  AVFrame *frame = outputStreams[index].frame;
  if (av_frame_make_writable(frame) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not make the video frame writable");
    return false;
  }
  return true;
}

- (void *__nonnull)getBaseAddress:(long)index ofPlane:(long)planeIndex {
  return outputStreams[index].frame->data[planeIndex];
}

- (bool)writeFrame:(OutputStream *)os {
  int ret;
  ret = avcodec_send_frame(os->codecContext, os->frame);
  if (ret < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Error sending a frame to the encoder: %s",
                     av_err2str(ret));
    return false;
  }

  while (ret >= 0) {
    ret = avcodec_receive_packet(os->codecContext, os->packet);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
      break;
    } else if (ret < 0) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                       "Error encoding a frame: %s", av_err2str(ret));
      return false;
    }

    av_packet_rescale_ts(os->packet, os->codecContext->time_base,
                         os->stream->time_base);
    os->packet->stream_index = os->stream->index;

    log_packet(formatContext, os->packet);
    ret = av_interleaved_write_frame(formatContext, os->packet);
    if (ret < 0) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                       "Error while writing output packet: %s",
                       av_err2str(ret));
      return false;
    }
  }

  return true;
}

- (BOOL)writeVideo:(int)index
            outputPTS:(int64_t)outputPTS {
  OutputStream *os = &outputStreams[index];

  os->frame->pts = outputPTS;

  [self writeFrame:os];

  return YES;
}

- (bool)writeAudio:(int)index outputPTS:(int64_t)outputPTS {
  OutputStream *os = &outputStreams[index];

  os->frame->pts =
      av_rescale_q(outputPTS, (AVRational){1, os->codecContext->sample_rate},
                   os->codecContext->time_base);
  [self writeFrame:os];

  return true;
}

- (void)finishStream:(int)index {
  OutputStream *os = &outputStreams[index];
  os->frame = NULL;
  [self writeFrame:os];
}

- (void)finishOutput {
  av_write_trailer(formatContext);
}

- (void)freeStream:(int)index {
  OutputStream *os = &outputStreams[index];
  avcodec_free_context(&os->codecContext);
  av_frame_free(&os->frame);
  av_packet_free(&os->packet);
}

- (void)freeOutput {
  avio_closep(&formatContext->pb);
  avformat_free_context(formatContext);
}
@end
