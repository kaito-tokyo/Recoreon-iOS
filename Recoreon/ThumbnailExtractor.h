#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ThumbnailExtractor : NSObject {
}
- (void)extract:(NSURL *__nonnull)videoURL
    thumbnailURL:(NSURL *__nonnull)thumbnailURL;
@end
