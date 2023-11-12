#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

@interface InputAudioSampleReader: NSObject {
}
@property(nonatomic) AudioConverterRef __nonnull audioConverter;
- (void)read:(CMSampleBufferRef __nonnull)sampleBuffer;
@end
