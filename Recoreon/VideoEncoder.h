#pragma once

#import "Foundation/Foundation.h"

@interface VideoEncoder : NSObject {
}
- (void)encode:(NSURL *)videoURL outputURL:(NSURL *)outputURL progressHandler:(void (^)(double progress))progressHandler completionHandler:(void (^)(BOOL isSuccessful))completionHandler;
@end
