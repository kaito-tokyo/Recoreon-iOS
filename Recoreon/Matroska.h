#pragma once

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface Matroska : NSObject {
}
- (int)open:(NSString *)filename;
- (int)writeVideo:(uint8_t *)yPlane yLinesize:(long)yLinesize cbcr:(uint8_t*)cbcrPlane cbcrLinesize:(long)cbcrLinesize;
- (int)writeAudio:(AudioBufferList *)audioBufferList;
- (int)close;
@end

