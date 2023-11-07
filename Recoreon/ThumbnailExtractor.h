#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ThumbnailExtractor : NSObject {
}
- (void)extract:(NSURL *)videoURL thumbnailURL:(NSURL *)thumbnailURL;
@end
