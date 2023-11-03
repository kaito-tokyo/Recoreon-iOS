#pragma once

#import <CoreMedia/CoreMedia.h>

@interface Matroska : NSObject {
}
- (int)open:(NSString *)filename;
- (void)writeVideo:(CMSampleBufferRef)sampleBuffer;
- (void)writeAudio:(CMSampleBufferRef)sampleBuffer;
- (int)close;
@end
