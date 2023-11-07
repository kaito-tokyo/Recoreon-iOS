#import "ThumbnailExtractor.h"

#include <ffmpegkit/FFmpegKit.h>

@implementation ThumbnailExtractor : NSObject
- (void)extract:(NSURL *)videoURL thumbnailURL:(NSURL *)thumbnailURL {
    NSString *cmdline = [NSString stringWithFormat:@"-y -i \"%@\" -vf thumbnail=500 -frames:v 1 \"%@\"", videoURL.path, thumbnailURL.path];
    FFmpegSession *session = [FFmpegKit execute:cmdline];
    ReturnCode *ret = [session getReturnCode];
    if ([ReturnCode isSuccess:ret]) {
        return;
    } else {
        NSLog(@"Some error occured!");
        return;
    }
}
@end
