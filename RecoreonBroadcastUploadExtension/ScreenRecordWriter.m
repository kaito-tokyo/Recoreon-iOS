#include <os/log.h>

#include <libavutil/timestamp.h>

#import "ScreenRecordWriter.h"

static void log_packet(const AVFormatContext *fmt_ctx, const AVPacket *pkt) {
#if DEBUG
//  AVRational *time_base = &fmt_ctx->streams[pkt->stream_index]->time_base;

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

- (bool)openOutputFile:(NSString *__nonnull)filename {
  _filename = filename;
  const char *path = [filename UTF8String];
  avformat_alloc_output_context2(&formatContext, NULL, NULL, path);
  if (formatContext == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not open an output file: %@", filename);
    return false;
  } else {
    return true;
  }
}

- (bool)addStream:(long)index {
  OutputStream *os = &outputStreams[index];

  os->packet = av_packet_alloc();
  if (!os->packet) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate a packet");
    return false;
  }

  os->stream = avformat_new_stream(formatContext, NULL);
  if (!os->stream) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate a stream");
    return false;
  }
  os->stream->id = (int)index;

  return true;
}

- (bool)addVideoStream:(long)index
                 width:(long)width
                height:(long)height
             frameRate:(long)frameRate
               bitRate:(long)bitRate {
  if (![self addStream:index]) {
    return false;
  }

  OutputStream *os = &outputStreams[index];

  AVCodecContext *codecContext = avcodec_alloc_context3(videoCodec);
  os->codecContext = codecContext;
  if (!codecContext) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate an video codec context");
    return false;
  }

  os->codecContext->codec_id = AV_CODEC_ID_H264;
  os->codecContext->bit_rate = bitRate;
  os->codecContext->width = (int)width;
  os->codecContext->height = (int)height;
  AVRational timeBase = {1, (int)frameRate};
  os->codecContext->time_base = timeBase;
  os->stream->time_base = timeBase;
  os->codecContext->gop_size = 12;
  os->codecContext->pix_fmt = AV_PIX_FMT_NV12;
  os->codecContext->color_range = AVCOL_RANGE_JPEG;
  os->codecContext->color_primaries = AVCOL_PRI_BT709;

  if (formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
    os->codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
  }

  return true;
}

- (bool)addAudioStream:(long)index
            sampleRate:(long)sampleRate
               bitRate:(long)bitRate {
  if (![self addStream:index]) {
    return false;
  }

  OutputStream *os = &outputStreams[index];

  os->codecContext = avcodec_alloc_context3(audioCodec);
  if (!os->codecContext) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate an audio codec context");
    return false;
  }

  os->codecContext->sample_fmt = AV_SAMPLE_FMT_S16;
  os->codecContext->bit_rate = bitRate;
  os->codecContext->sample_rate = (int)sampleRate;
  AVChannelLayout layout = AV_CHANNEL_LAYOUT_STEREO;
  av_channel_layout_copy(&os->codecContext->ch_layout, &layout);
  AVRational timeBase = {1, (int)sampleRate};
  os->codecContext->time_base = timeBase;
  os->stream->time_base = timeBase;

  if (formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
    os->codecContext->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
  }

  return true;
}

- (bool)openVideo:(long)index {
  OutputStream *os = &outputStreams[index];
  if (avcodec_open2(os->codecContext, videoCodec, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not open the video codec context");
    return false;
  }

  os->frame = av_frame_alloc();
  if (os->frame == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate a video frame");
    return false;
  }

  os->frame->format = os->codecContext->pix_fmt;
  os->frame->width = os->codecContext->width;
  os->frame->height = os->codecContext->height;
  os->frame->color_range = AVCOL_RANGE_JPEG;

  if (av_frame_get_buffer(os->frame, 0) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate a video frame buffer");
    return false;
  }

  if (avcodec_parameters_from_context(os->stream->codecpar, os->codecContext) <
      0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not copy the video stream parameters");
    return false;
  }

  return true;
}

- (bool)openAudio:(long)index {
  OutputStream *os = &outputStreams[index];
  if (avcodec_open2(os->codecContext, audioCodec, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not open the audio codec context");
    return false;
  }

  os->frame = av_frame_alloc();
  if (os->frame == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate an audio frame");
    return false;
  }

  os->frame->format = os->codecContext->sample_fmt;
  av_channel_layout_copy(&os->frame->ch_layout, &os->codecContext->ch_layout);
  os->frame->sample_rate = os->codecContext->sample_rate;
  os->frame->nb_samples = os->codecContext->frame_size;

  if (av_frame_get_buffer(os->frame, 0) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not allocate an audio frame buffer");
    return false;
  }

  if (avcodec_parameters_from_context(os->stream->codecpar, os->codecContext) <
      0) {
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
                     "Could not open the file io: %s", path);
    return false;
  }

  if (avformat_write_header(formatContext, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not write the header");
    return false;
  }

  return true;
}

- (bool)makeFrameWritable:(long)index {
  OutputStream *os = &outputStreams[index];
  if (av_frame_make_writable(os->frame) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR,
                     "Could not make the frame writable");
    return false;
  }
  return true;
}

- (long)getWidth:(long)index {
  return outputStreams[index].frame->width;
}

- (long)getHeight:(long)index {
  return outputStreams[index].frame->height;
}

- (long)getBytesPerRow:(long)index ofPlane:(long)planeIndex {
  return outputStreams[index].frame->linesize[planeIndex];
}

- (long)getNumSamples:(long)index {
  return outputStreams[index].frame->nb_samples;
}

- (void *__nonnull)getBaseAddress:(long)index ofPlane:(long)planeIndex {
  return outputStreams[index].frame->data[planeIndex];
}

- (bool)writeFrame:(long)index {
  OutputStream *os = &outputStreams[index];

  int ret = avcodec_send_frame(os->codecContext, os->frame);
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

- (bool)writeVideo:(long)index outputPTS:(int64_t)outputPTS {
  outputStreams[index].frame->pts = outputPTS;

  if (![self writeFrame:index]) {
    return false;
  }

  return true;
}

- (bool)writeAudio:(long)index outputPTS:(int64_t)outputPTS {
  OutputStream *os = &outputStreams[index];
  AVCodecContext *c = os->codecContext;
  outputStreams[index].frame->pts =
      av_rescale_q(outputPTS, (AVRational){1, c->sample_rate}, c->time_base);

  if (![self writeFrame:index]) {
    return false;
  }

  return true;
}

- (bool)ensureResamplerIsInitialted:(long)index sampleRate:(double)sampleRate numChannels:(uint32_t)numChannels {
  OutputStream *os = &outputStreams[index];
  if (os->swrContext == NULL) {
    os->swrContext = swr_alloc();
  }
  SwrContext *c = os->swrContext;
  if (c == NULL) {
    return false;
  }

  if (sampleRate == os->sampleRate && numChannels == os->numChannels) {
    return true;
  }

  swr_close(c);

  if (numChannels == 1) {
    av_opt_set_chlayout(c, "in_chlayout", &(AVChannelLayout)AV_CHANNEL_LAYOUT_MONO, 0);
  } else if (numChannels == 2) {
    av_opt_set_chlayout(c, "in_chlayout", &(AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO, 0);
  }
  av_opt_set_int(c, "in_sample_rate", sampleRate, 0);
  av_opt_set_sample_fmt(c, "in_sample_fmt", AV_SAMPLE_FMT_S16, 0);
  av_opt_set_chlayout(c, "out_chlayout", &os->codecContext->ch_layout, 0);
  av_opt_set_int(c, "out_sample_rate", os->codecContext->sample_rate, 0);
  av_opt_set_sample_fmt(c, "out_sample_fmt", os->codecContext->sample_fmt, 0);

  if (swr_init(c) < 0) {
    return false;
  }

  os->sampleRate = sampleRate;
  os->numChannels = numChannels;

  return true;
}

- (bool)writeAudioWithResampling:(long)index outputPTS:(int64_t)outputPTS data:(const uint8_t *)inData count:(int)inCount {
  OutputStream *os = &outputStreams[index];
  AVCodecContext *c = os->codecContext;
  outputStreams[index].frame->pts =
      av_rescale_q(outputPTS, (AVRational){1, c->sample_rate}, c->time_base);

  if (swr_convert(os->swrContext, os->frame->data, os->frame->nb_samples, &inData, inCount) < 0) {
    return false;
  }

  if (![self writeFrame:index]) {
    return false;
  }

  return true;
}

- (void)finishStream:(long)index {
  OutputStream *os = &outputStreams[index];
  AVFrame *origFrame = os->frame;
  os->frame = NULL;
  [self writeFrame:index];
  os->frame = origFrame;
}

- (void)finishOutput {
  av_write_trailer(formatContext);
}

- (void)closeStream:(long)index {
  OutputStream *os = &outputStreams[index];
  avcodec_free_context(&os->codecContext);
  av_frame_free(&os->frame);
  av_packet_free(&os->packet);
}

- (void)closeOutput {
  avio_closep(&formatContext->pb);
  avformat_free_context(formatContext);
}
@end
