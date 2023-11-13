#include <os/log.h>

#import "ScreenRecordWriter.h"

@implementation ScreenRecordWriter

- (BOOL)openVideoCodec:(NSString *__nonnull)name {
  videoCodec = avcodec_find_encoder_by_name([name UTF8String]);
  if (videoCodec == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not find a video encoder: %@", name);
    return NO;
  } else {
    return YES;
  }
}

- (BOOL)openAudioCodec:(NSString *__nonnull)name {
  audioCodec = avcodec_find_encoder_by_name([name UTF8String]);
  if (audioCodec == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not find an audio encoder: %@", name);
    return NO;
  } else {
    return YES;
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

- (BOOL)addStream:(int)index {
  OutputStream *os = &outputStreams[index];

  os->packet = av_packet_alloc();
  if (!os->packet) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate a packet");
    return NO;
  }

  AVStream *stream = avformat_new_stream(formatContext, NULL);
  if (!stream) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate a stream");
    return NO;
  }
  stream->id = index;
  os->stream = stream;

  return YES;
}

- (BOOL)addVideoStream:(int)index
                 width:(int)width
                height:(int)height
             frameRate:(int)frameRate
               bitRate:(int)bitRate {
  if (![self addStream:index]) {
    return NO;
  }

  OutputStream *os = &outputStreams[index];

  AVCodecContext *c = avcodec_alloc_context3(videoCodec);
  if (!c) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate an video codec context");
    return NO;
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

  return YES;
}

- (BOOL)addAudioStream:(int)index
            sampleRate:(int)sampleRate
               bitRate:(int)bitRate {
  if (![self addStream:index]) {
    return NO;
  }

  OutputStream *os = &outputStreams[index];

  AVCodecContext *c = avcodec_alloc_context3(audioCodec);
  if (!c) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not allocate an video codec context");
    return NO;
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

  return YES;
}

- (BOOL)openVideo:(int)index {
  OutputStream *os = &outputStreams[index];
  AVCodecContext *codecContext = os->codecContext;
  if (avcodec_open2(codecContext, videoCodec, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not open video codec context");
    return NO;
  }

  AVFrame *frame = av_frame_alloc();
  if (frame == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not allocate video frame");
    return NO;
  }

  frame->format = codecContext->pix_fmt;
  frame->width = codecContext->width;
  frame->height = codecContext->height;
  frame->color_range = AVCOL_RANGE_JPEG;

  if (av_frame_get_buffer(frame, 0) < 0) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not allocate video frame buffer");
      return NO;
  }

  os->frame = frame;

  if (avcodec_parameters_from_context(os->stream->codecpar, codecContext) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not copy the video stream parameters");
    return NO;
  }

  return YES;
}

- (BOOL)openAudio:(int)index {
  OutputStream *os = &outputStreams[index];
  AVCodecContext *codecContext = os->codecContext;
  if (avcodec_open2(codecContext, audioCodec, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not open audio codec context");
    return NO;
  }

  AVFrame *frame = av_frame_alloc();
  if (frame == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not allocate audio frame");
    return NO;
  }

  frame->format = codecContext->sample_fmt;
  av_channel_layout_copy(&frame->ch_layout, &codecContext->ch_layout);
  frame->sample_rate = codecContext->sample_rate;
  frame->nb_samples = codecContext->frame_size;

  if (av_frame_get_buffer(frame, 0) < 0) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not allocate video frame buffer");
        return NO;
  }

  os->frame = frame;

  if (avcodec_parameters_from_context(os->stream->codecpar, codecContext) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not copy the audio stream parameters");
    return NO;
  }

  return YES;
}

- (BOOL)checkIfVideoSampleBufferIsValid:(CMSampleBufferRef __nonnull)sampleBuffer {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixelBuffer == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not get the pixel buffer");
    return NO;
  }

  OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  if (pixelFormat != kCVPixelFormatType_420YpCbCr10BiPlanarFullRange) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "The pixel format is not supported: %u", pixelFormat);
    return NO;
  }

  return YES;
}

- (void)writeVideo:(int)index
         sampleBuffer:(CMSampleBufferRef __nonnull)sampleBuffer
          pixelBuffer:(CVPixelBufferRef __nonnull)pixelBuffer
             lumaData:(void *__nonnull)lumaData
           chromaData:(void *__nonnull)chromaData
      lumaBytesPerRow:(long)lumaBytesPerRow
    chromaBytesPerRow:(long)chromaBytesPerRow {
  AVFrame *frame = outputStream->frame;
  if (av_frame_make_writable(frame) < 0) {
    NSLog(@"Could not make a frame writable!");
    return;
  }

  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  copyPlane(frame->data[0], frame->linesize[0], lumaData, lumaBytesPerRow,
            width, height);
  copyPlane(frame->data[1], frame->linesize[1], chromaData, chromaBytesPerRow,
            width, height / 2);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
  if (screenBasePts == 0.0) {
    screenBasePts = pts.value;
  }
  screenVideoStream.frame->pts =
      (pts.value - screenBasePts) * STREAM_FRAME_RATE / pts.timescale;

  write_frame(outputFormatContext, outputStream->enc, outputStream->st,
              outputStream->frame, outputStream->tmp_pkt);
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
