#import <os/log.h>
#import <AudioToolbox/AudioToolbox.h>

#import "InputAudioSampleReader.h"

@implementation InputAudioSampleReader
- (void)read:(CMSampleBufferRef)sampleBuffer buf:(void *)buf bufSize:(size_t)bufSize handler:(void (^)(void))handler {
  AudioBufferList abl;
  CMBlockBufferRef blockBuffer;
  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &abl, sizeof(AudioBufferList), nil, nil, 0, &blockBuffer);
  if (blockBuffer == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not get the audio buffer!");
    return;
  }

  CMFormatDescriptionRef format =
      CMSampleBufferGetFormatDescription(sampleBuffer);
  if (format == nil) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not get the format description!");
    return;
  }

  const AudioStreamBasicDescription *asbd =
      CMAudioFormatDescriptionGetStreamBasicDescription(format);
  if (asbd == NULL) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "Could not get the audio stream basic description!");
    return;
  }

  [self checkIfCompatible:asbd abl:&abl];

  audioConverter->
}

- (void)logInformation:(const AudioStreamBasicDescription *)asbd abl:(const AudioBufferList *)abl {
  os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEBUG,
                   "formatID:%u sampleRate:%lf bitPerChannel:%u "
                   "channelPerFrame:%u numberBuffers:%u dataByteSize:%u",
                   asbd->mFormatID, asbd->mSampleRate, asbd->mChannelsPerFrame,
                   asbd->mBitsPerChannel, abl->mNumberBuffers,
                   abl->mBuffers[0].mDataByteSize);
}
- (BOOL)checkIfCompatible:(const AudioStreamBasicDescription *)asbd abl:(const AudioBufferList *)abl {
  if (asbd->mFormatID != kAudioFormatLinearPCM) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The format is not supported: %u!", asbd->mFormatID);
    [self logInformation:asbd abl:abl];
    return false;
  }

//  if (asbd->mSampleRate != sampleRate) {
//    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
//                     "The sample rate is not supported: %lf!",
//                     asbd->mSampleRate);
//    [self logInformation:asbd abl:abl];
//    return false;
//  }

  if (asbd->mBitsPerChannel != 16) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The bits per channel is not supported: %u!",
                     asbd->mBitsPerChannel);
    [self logInformation:asbd abl:abl];
    return false;
  }

  if (abl->mNumberBuffers != 1) {
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                     "The audio buffer is not interleaved: %u!",
                     abl->mNumberBuffers);
    [self logInformation:asbd abl:abl];
    return false;
  }

  if (asbd->mChannelsPerFrame == 1) {
    if (abl->mBuffers[0].mDataByteSize != 2048) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                       "The size of the audio buffer is not 2048: %u!",
                       abl->mBuffers[0].mDataByteSize);
      return false;
    }
  } else if (asbd->mChannelsPerFrame == 2) {
    if (abl->mBuffers[0].mDataByteSize != 4096) {
      os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_INFO,
                       "The size of the audio buffer is not 4096: %u!",
                       abl->mBuffers[0].mDataByteSize);
      return false;
    }
  } else {
    NSLog(@"The channels per frame is not supported!");
    return false;
  }

  return true;
}
@end
