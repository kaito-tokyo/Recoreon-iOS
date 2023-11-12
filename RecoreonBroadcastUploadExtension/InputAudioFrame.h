#pragma once

#import <CoreMedia/CoreMedia.h>

@interface InputAudioFrame : NSObject {
  CMSampleBufferRef __nonnull sampleBuffer;
  double sampleRate;

  AudioBufferList audioBufferList;
  CMBlockBufferRef __nonnull blockBuffer;
  CMFormatDescriptionRef __nonnull format;
  const AudioStreamBasicDescription *__nonnull desc;
}
- (instancetype __nullable)initWithSampleBuffer:
                               (CMSampleBufferRef __nonnull)sampleBuffer
                                     sampleRate:(double)sampleRate;
- (BOOL)checkIfCompatible;
- (void)loadDataToBuffer:(int16_t *__nonnull)buffer size:(size_t)size;
@end
