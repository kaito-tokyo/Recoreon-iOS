#import "VideoEncoder.h"

extern "C" {
#include <ffmpegkit/FFmpegKit.h>
}

@implementation VideoEncoder : NSObject
- (void)encode:(NSURL *)videoURL outputURL:(NSURL *)outputURL {
    NSString *cmdline = [NSString stringWithFormat:@"-y -i \"%@\" -c:v h264_videotoolbox -vf setpts=PTS/4 -af atempo=4 -r 60 \"%@\"", videoURL.path, outputURL.path];
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
