#pragma once

#import <CoreMedia/CoreMedia.h>

@interface Matroska : NSObject {
    bool basePtsInitialized;
    double basePts;
}
- (int)open:(NSString *)filename;
- (void)writeVideo:(CMSampleBufferRef)sampleBuffer pixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)writeAudio:(CMSampleBufferRef)sampleBuffer;
- (int)close;
@end
