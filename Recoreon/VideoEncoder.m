#import "VideoEncoder.h"

#include <ffmpegkit/FFmpegKit.h>
#include <ffmpegkit/FFprobeKit.h>
#include <ffmpegkit/MediaInformation.h>
#include <ffmpegkit/MediaInformationSession.h>

double getDuration(NSString *videoPath) {
  MediaInformationSession *session = [FFprobeKit getMediaInformation:videoPath];
  MediaInformation *info = [session getMediaInformation];
  NSString *duration = [info getDuration];
  return [duration doubleValue];
}

@implementation VideoEncoder : NSObject
- (void)encode:(NSURL *)videoURL
            outputURL:(NSURL *)outputURL
      progressHandler:(void (^)(double progress))progressHandler
    completionHandler:(void (^)(BOOL isSuccessful))completionHandler {
  double origDuration = getDuration(videoURL.path);
  double targetTime = origDuration / 4.0 * 1000.0;
  NSArray *args = @[
    @"-y",
    @"-i",
    videoURL.path,
    @"-c:v",
    @"h264_videotoolbox",
    @"-vb",
    @"1000k",
    @"-c:a",
    @"aac_at",
    @"-filter_complex",
    @"[0:0] setpts=PTS/4 [a]; [0:1] atempo=4 [b]; [0:2] aresample=async=1:first_pts=0 [c0]; [c0] atempo=4 [c1]",
    @"-r",
    @"60",
    @"-map",
    @"[a]",
    @"-map",
    @"[b]",
    @"-map",
    @"[c1]",
    outputURL.path,
  ];
  [FFmpegKit executeWithArgumentsAsync:args
      withCompleteCallback:^(FFmpegSession *session) {
        ReturnCode *ret = [session getReturnCode];
        if ([ReturnCode isSuccess:ret]) {
          completionHandler(true);
          return;
        } else {
          NSLog(@"Some error occured!");
          completionHandler(false);
          return;
        }
      }
      withLogCallback:^(Log *log) {
      }
      withStatisticsCallback:^(Statistics *statistics) {
        double progressTime = [statistics getTime];
        progressHandler(progressTime / targetTime);
      }];
}
@end
