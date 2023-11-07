#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ThumbnailExtractor : NSObject {
}
- (UIImage *)extract:(NSURL *)videoURL thumbnailURL:(NSURL *)thumbnailURL;
@end
