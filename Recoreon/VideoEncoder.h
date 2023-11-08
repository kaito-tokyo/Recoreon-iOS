#pragma once

#import "Foundation/Foundation.h"

@interface VideoEncoder : NSObject {
}
- (void)encode:(NSURL *__nonnull)videoURL
            outputURL:(NSURL *__nonnull)outputURL
      progressHandler:(void (^__nonnull)(double progress))progressHandler
    completionHandler:(void (^__nonnull)(BOOL isSuccessful))completionHandler;
@end
