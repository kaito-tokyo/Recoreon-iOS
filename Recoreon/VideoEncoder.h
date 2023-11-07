#pragma once

#import "Foundation/Foundation.h"

@interface VideoEncoder : NSObject {
}
- (void)encode:(NSURL *)videoURL outputURL:(NSURL *)outputURL;
@end
