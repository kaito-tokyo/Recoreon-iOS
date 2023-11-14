#include <os/log.h>

#import "ScreenRecordWriter.h"

static void copyPlane(uint8_t *dst, size_t dstLinesize, uint8_t *src,
                      size_t srcLinesize, size_t height) {
  if (dstLinesize == srcLinesize) {
    memcpy(dst, src, dstLinesize * height);
  } else {
    for (int i = 0; i < height; i++) {
      memcpy(&dst[dstLinesize * i], &src[srcLinesize * i], MIN(srcLinesize, dstLinesize));
    }
  }
}

static bool isASBDEqual(const AudioStreamBasicDescription *x, const AudioStreamBasicDescription *y) {
  return x->mSampleRate == y->mSampleRate && x->mFormatID == y->mFormatID && x->mFormatFlags == y->mFormatFlags && x->mBytesPerPacket == y->mBytesPerPacket && x->mFramesPerPacket == y->mFramesPerPacket && x->mBytesPerFrame == y->mBytesPerFrame && x->mChannelsPerFrame == y->mChannelsPerFrame && x->mBitsPerChannel == y->mBitsPerChannel;
}

static OSStatus audioConvertProc(AudioConverterRef inAudioConverter, uint32_t *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription * __nullable * __nullable outDataPacketDescription, void * __nullable inUserData) {
  ScreenRecordWriter *self = (__bridge ScreenRecordWriter *)inUserData;
  *ioData = *self->abl;
//  ioData->mNumberBuffers = 1;
//  ioData->mBuffers[0].mNumberChannels = 2;
//  ioData->mBuffers[0].mDataByteSize = 4096;
//  ioData->mBuffers[0].mData = self->buf;
//  memcpy(<#void *dst#>, <#const void *src#>, <#size_t n#>)
//  self->buf[0] = 100;
//  self->buf[1] = 200;
//  self->buf[2] = 300;
//  self->buf[3] = 400;
  return noErr;
}

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
  os->stream->time_base = timeBase;

  if (formatContext->oformat->flags & AVFMT_GLOBALHEADER) {
    c->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
  }

  AudioStreamBasicDescription asbd = {
    .mSampleRate = sampleRate,
    .mFormatID = kAudioFormatLinearPCM,
    .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
    .mBytesPerPacket = 4,
    .mFramesPerPacket = 1,
    .mBytesPerFrame = 4,
    .mChannelsPerFrame = 2,
    .mBitsPerChannel = 16
  };
  os->outputASBD = asbd;

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

- (BOOL)startOutput {
  const char *path = [_filename UTF8String];
  av_dump_format(formatContext, 0, path, 1);

  if (avio_open(&formatContext->pb, path, AVIO_FLAG_WRITE) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not open the file io:%@", _filename);
    return NO;
  }

  if (avformat_write_header(formatContext, NULL) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not write the header");
    return NO;
  }

  return YES;
}

- (BOOL)checkIfVideoSampleIsValid:(CMSampleBufferRef __nonnull)sampleBuffer {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixelBuffer == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not get the pixel buffer");
    return NO;
  }

  OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  if (pixelFormat != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "The pixel format is not supported: %u", pixelFormat);
    return NO;
  }

  return YES;
}

- (BOOL)writeFrame:(OutputStream *)os {
  int ret;
  ret = avcodec_send_frame(os->codecContext, os->frame);
  if (ret < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Error sending a frame to the encoder: %s", av_err2str(ret));
    return NO;
  }

  while (ret >= 0) {
    ret = avcodec_receive_packet(os->codecContext, os->packet);
    if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
      break;
    } else if (ret < 0) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Error encoding a frame: %s", av_err2str(ret));
      return NO;
    }

    av_packet_rescale_ts(os->packet, os->codecContext->time_base, os->stream->time_base);
    os->packet->stream_index = os->stream->index;

    ret = av_interleaved_write_frame(formatContext, os->packet);
    if (ret < 0) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Error while writing output packet: %s", av_err2str(ret));
      return NO;
    }
  }

  return YES;
}

- (BOOL)writeVideo:(int)index
             lumaData:(void *__nonnull)lumaData
           chromaData:(void *__nonnull)chromaData
      lumaBytesPerRow:(long)lumaBytesPerRow
    chromaBytesPerRow:(long)chromaBytesPerRow
            height:(long)height
               pts:(CMTime)pts {
  OutputStream *os = &outputStreams[index];
  AVFrame *frame = os->frame;
  if (av_frame_make_writable(frame) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not make the video frame writable");
    return NO;
  }

  copyPlane(frame->data[0], frame->linesize[0], lumaData, lumaBytesPerRow, height);
  copyPlane(frame->data[1], frame->linesize[1], chromaData, chromaBytesPerRow, height / 2);

  AVRational *timeBase = &os->codecContext->time_base;
  frame->pts = pts.value * timeBase->num / timeBase->den / pts.timescale;

  [self writeFrame:os];

  return YES;
}

- (bool)ensureAudioConverterAvailable:(int)index asbd:(const AudioStreamBasicDescription *)asbd {
  OSStatus status;
  OutputStream *os = &outputStreams[index];

  if (!isASBDEqual(&os->inputASBD, asbd)) {
    if (os->audioConverter != NULL) {
      status = AudioConverterDispose(os->audioConverter);
      if (status != noErr) {
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO, "Could not dispose the audio converter: %d", status);
      }
    }
    status = AudioConverterNew(asbd, &os->outputASBD, &os->audioConverter);
    if (status != noErr) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not create the audio converter: %d", status);
      return false;
    }
    os->inputASBD = *asbd;
  }
  if (os->audioConverter == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not find the audio converter");
    return false;
  }

  return true;
}

- (void)listenToResampleAudioFrame:(int)index numSamples:(uint32_t *)numSamples fillBufList:(AudioBufferList *)fillBufList {
  OutputStream *os = &outputStreams[index];
  AudioConverterFillComplexBuffer(os->audioConverter, audioConvertProc, (__bridge void *)self, numSamples, fillBufList, NULL);
}

- (bool)writeAudio:(int)index
               abl:(AudioBufferList *__nonnull)abl
              asbd:(const AudioStreamBasicDescription *__nonnull)asbd
         outputPts:(int64_t)outputPts {
  OutputStream *os = &outputStreams[index];

  if (av_frame_make_writable(os->frame) < 0) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "Could not make the audio frame writable");
    return false;
  }

  if (![self ensureAudioConverterAvailable:index asbd:asbd]) {
    return false;
  }

  os->frame->pts = outputPts;

  AudioBufferList outputABL;
  outputABL.mNumberBuffers = 1;
  outputABL.mBuffers[0].mNumberChannels = 2;
  outputABL.mBuffers[0].mDataByteSize = os->frame->nb_samples * 4;
  outputABL.mBuffers[0].mData = os->frame->data[0];

  uint32_t numSamples = os->frame->nb_samples;

  self->abl = abl;

  AudioConverterFillComplexBuffer(os->audioConverter, &audioConvertProc, (__bridge void *)self, &numSamples, &outputABL, NULL);

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
