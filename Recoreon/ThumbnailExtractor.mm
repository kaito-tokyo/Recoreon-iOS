#import "ThumbnailExtractor.h"

extern "C" {
#include <ffmpegkit/FFmpegKit.h>
}

@implementation ThumbnailExtractor : NSObject
- (UIImage *)extract:(NSURL *)videoURL thumbnailURL:(NSURL *)thumbnailURL {
    NSString *cmdline = [NSString stringWithFormat:@"-y -i \"%@\" -vf thumbnail=500 -frames:v 1 \"%@\"", videoURL.path, thumbnailURL.path];
    FFmpegSession *session = [FFmpegKit execute:cmdline];
    ReturnCode *ret = [session getReturnCode];
    if ([ReturnCode isSuccess:ret]) {
        return [UIImage imageWithContentsOfFile:thumbnailURL.path];
    } else {
        NSLog(@"Some error occured!");
        return NULL;
    }
}
@end
