#import <os/log.h>

#import "InputAudioFrame.h"

@implementation InputAudioFrame
- (instancetype __nullable)init {
  return nil;
}
- (instancetype __nullable)initWithSampleBuffer:
                               (CMSampleBufferRef __nonnull)sampleBuffer
                                     sampleRate:(double)sampleRate {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  self->sampleBuffer = sampleBuffer;
  self->sampleRate = sampleRate;

  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer, nil, &audioBufferList, sizeof(AudioBufferList), nil, nil, 0,
      &blockBuffer);
  if (blockBuffer == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not get the audio buffer!");
    return nil;
  }

  CMFormatDescriptionRef format =
      CMSampleBufferGetFormatDescription(sampleBuffer);
  if (format == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not get the format description!");
    return nil;
  }
  self->format = CMSampleBufferGetFormatDescription(sampleBuffer);

  const AudioStreamBasicDescription *desc =
      CMAudioFormatDescriptionGetStreamBasicDescription(format);
  if (desc == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not get the audio stream basic description!");
    return nil;
  }
  self->desc = desc;

  return self;
}
- (void)logInformation {
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,
                   "formatID:%u sampleRate:%lf bitPerChannel:%u "
                   "channelPerFrame:%u numberBuffers:%u dataByteSize:%u",
                   desc->mFormatID, desc->mSampleRate, desc->mChannelsPerFrame,
                   desc->mBitsPerChannel, audioBufferList.mNumberBuffers,
                   audioBufferList.mBuffers[0].mDataByteSize);
}
- (BOOL)checkIfCompatible {
  if (desc->mFormatID != kAudioFormatLinearPCM) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The format is not supported: %u!", desc->mFormatID);
    [self logInformation];
    return false;
  }

  if (desc->mSampleRate != sampleRate) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The sample rate is not supported: %lf!",
                     desc->mSampleRate);
    [self logInformation];
    return false;
  }

  if (desc->mBitsPerChannel != 16) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The bits per channel is not supported: %u!",
                     desc->mBitsPerChannel);
    [self logInformation];
    return false;
  }

  if (audioBufferList.mNumberBuffers != 1) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The audio buffer is not interleaved: %u!",
                     audioBufferList.mNumberBuffers);
    [self logInformation];
    return false;
  }

  if (desc->mChannelsPerFrame == 1) {
    if (audioBufferList.mBuffers[0].mDataByteSize != 2048) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                       "The size of the audio buffer is not 2048: %u!",
                       audioBufferList.mBuffers[0].mDataByteSize);
      return false;
    }
  } else if (desc->mChannelsPerFrame == 2) {
    if (audioBufferList.mBuffers[0].mDataByteSize != 4096) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                       "The size of the audio buffer is not 4096: %u!",
                       audioBufferList.mBuffers[0].mDataByteSize);
      return false;
    }
  } else {
    NSLog(@"The channels per frame is not supported!");
    return false;
  }

  return true;
}
- (void)loadDataToBuffer:(int16_t *__nonnull)buffer size:(size_t)size {
  if (desc->mChannelsPerFrame == 2 &&
      (desc->mFormatFlags & kAudioFormatFlagIsBigEndian)) {
    uint16_t *buf = (uint16_t *)audioBufferList.mBuffers[0].mData;
    for (int i = 0; i < size / 2; i++) {
      uint16_t unsigned16Value = CFSwapInt16BigToHost(buf[i]);
      buffer[i] = *(int16_t *)&unsigned16Value;
    }
  } else if (desc->mChannelsPerFrame == 1 &&
             !(desc->mFormatFlags & kAudioFormatFlagIsBigEndian)) {
    int16_t *buf = (int16_t *)audioBufferList.mBuffers[0].mData;
    for (int i = 0; i < size / 4; i++) {
      buffer[i * 2] = buffer[i * 2 + 1] = buffer[i];
    }
  }
}
@end
