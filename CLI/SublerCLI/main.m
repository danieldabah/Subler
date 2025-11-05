//
//  main.m
//  SublerCLI
//
//  Created by Cursor on 2025-11-05.
//

#import <Foundation/Foundation.h>
#import <math.h>
#import <MP42Foundation/MP42Foundation.h>

static void printUsage(void) {
    fprintf(stderr, "Usage: sublercli <input> [options]\n");
    fprintf(stderr, "\nOptions:\n");
    fprintf(stderr, "  -o, --output <path>     Output MP4/M4V file path (defaults to input name with .m4v).\n");
    fprintf(stderr, "      --force-hvc1         Force hvc1 fourcc for HEVC video.\n");
    fprintf(stderr, "      --optimize           Run MP4 optimization pass after muxing.\n");
    fprintf(stderr, "      --audio-bitrate <k>  AAC fallback bitrate per channel in kbps (default 96).\n");
    fprintf(stderr, "      --mixdown <mode>     Audio mixdown: stereo (default), mono, dolby, dolbypl2, none.\n");
    fprintf(stderr, "      --drc <value>        Audio dynamic range compression (0.0-1.0, default 0).\n");
    fprintf(stderr, "      --overwrite          Overwrite existing output file.\n");
    fprintf(stderr, "      --no-progress        Disable progress output.\n");
    fprintf(stderr, "      --help               Display this help message.\n");
}

static MP42AudioMixdown mixdownFromString(NSString *value) {
    if (!value) { return kMP42AudioMixdown_Stereo; }

    NSString *lower = value.lowercaseString;
    if ([lower isEqualToString:@"mono"]) {
        return kMP42AudioMixdown_Mono;
    } else if ([lower isEqualToString:@"stereo"]) {
        return kMP42AudioMixdown_Stereo;
    } else if ([lower isEqualToString:@"dolby"]) {
        return kMP42AudioMixdown_Dolby;
    } else if ([lower isEqualToString:@"dolbypl2"] || [lower isEqualToString:@"dolbyplii"]) {
        return kMP42AudioMixdown_DolbyPlII;
    } else if ([lower isEqualToString:@"none"]) {
        return kMP42AudioMixdown_None;
    }

    fprintf(stderr, "Unknown mixdown '%s', defaulting to stereo.\n", value.UTF8String);
    return kMP42AudioMixdown_Stereo;
}

@interface CLIConsoleLogger : NSObject <MP42Logging>
@property (nonatomic) BOOL verbose;
@end

@implementation CLIConsoleLogger

- (void)writeToLog:(NSString *)string {
    if (self.verbose) {
        fprintf(stderr, "%s\n", string.UTF8String);
    }
}

- (void)writeErrorToLog:(NSError *)error {
    fprintf(stderr, "Error: %s\n", error.localizedDescription.UTF8String);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        NSMutableArray<NSString *> *arguments = [processInfo.arguments mutableCopy];
        if (arguments.count > 0) {
            [arguments removeObjectAtIndex:0];
        }

        NSString *inputPath = nil;
        NSString *outputPath = nil;
        BOOL forceHvc1 = NO;
        BOOL optimize = NO;
        BOOL overwrite = NO;
        BOOL showProgress = YES;
        BOOL verbose = NO;
        float drc = 0.0f;
        long audioBitrate = 96; // Per channel kbps, matches Subler default.
        MP42AudioMixdown mixdown = kMP42AudioMixdown_Stereo;

        for (NSUInteger index = 0; index < arguments.count; index++) {
            NSString *arg = arguments[index];
            if ([arg isEqualToString:@"-o"] || [arg isEqualToString:@"--output"]) {
                if (++index >= arguments.count) { fprintf(stderr, "Missing value for %s\n", arg.UTF8String); return 1; }
                outputPath = arguments[index];
            } else if ([arg isEqualToString:@"--force-hvc1"]) {
                forceHvc1 = YES;
            } else if ([arg isEqualToString:@"--optimize"]) {
                optimize = YES;
            } else if ([arg isEqualToString:@"--overwrite"]) {
                overwrite = YES;
            } else if ([arg isEqualToString:@"--audio-bitrate"]) {
                if (++index >= arguments.count) { fprintf(stderr, "Missing value for --audio-bitrate\n"); return 1; }
                audioBitrate = strtol(arguments[index].UTF8String, NULL, 10);
                if (audioBitrate <= 0) { audioBitrate = 96; }
            } else if ([arg isEqualToString:@"--mixdown"]) {
                if (++index >= arguments.count) { fprintf(stderr, "Missing value for --mixdown\n"); return 1; }
                mixdown = mixdownFromString(arguments[index]);
            } else if ([arg isEqualToString:@"--drc"]) {
                if (++index >= arguments.count) { fprintf(stderr, "Missing value for --drc\n"); return 1; }
                drc = strtof(arguments[index].UTF8String, NULL);
                if (drc < 0.0f) drc = 0.0f;
                if (drc > 1.0f) drc = 1.0f;
            } else if ([arg isEqualToString:@"--no-progress"]) {
                showProgress = NO;
            } else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--verbose"]) {
                verbose = YES;
            } else if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                printUsage();
                return 0;
            } else if ([arg hasPrefix:@"-"]) {
                fprintf(stderr, "Unknown option: %s\n\n", arg.UTF8String);
                printUsage();
                return 1;
            } else if (!inputPath) {
                inputPath = arg;
            } else if (!outputPath) {
                outputPath = arg;
            } else {
                fprintf(stderr, "Unexpected extra argument: %s\n", arg.UTF8String);
                return 1;
            }
        }

        if (!inputPath) {
            printUsage();
            return 1;
        }

        NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
        if (![[NSFileManager defaultManager] fileExistsAtPath:inputURL.path]) {
            fprintf(stderr, "Input file not found: %s\n", inputURL.path.UTF8String);
            return 1;
        }

        if (!outputPath) {
            NSString *basename = [[inputURL URLByDeletingPathExtension] lastPathComponent];
            NSURL *dir = [inputURL URLByDeletingLastPathComponent];
            outputPath = [[dir URLByAppendingPathComponent:basename] URLByAppendingPathExtension:@"m4v"].path;
        }

        NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:outputURL.path] && !overwrite) {
            fprintf(stderr, "Output file exists. Use --overwrite to replace: %s\n", outputURL.path.UTF8String);
            return 1;
        }

        CLIConsoleLogger *logger = [[CLIConsoleLogger alloc] init];
        logger.verbose = verbose;
        [MP42File setGlobalLogger:logger];

        NSError *error = nil;
        MP42FileImporter *importer = [[MP42FileImporter alloc] initWithURL:inputURL error:&error];
        if (!importer) {
            fprintf(stderr, "Failed to open input: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        MP42File *mp4 = [[MP42File alloc] init];
        [mp4.metadata merge:importer.metadata];

        NSMutableArray<MP42Track *> *addedTracks = [NSMutableArray array];

        for (MP42Track *track in importer.tracks) {
            if ([track isKindOfClass:[MP42VideoTrack class]]) {
                if (!isTrackMuxable(track.format)) {
                    fprintf(stderr, "Skipping non-MP4-safe video track %u\n", track.trackId);
                    continue;
                }
                [mp4 addTrack:track];
                [addedTracks addObject:track];
            } else if ([track isKindOfClass:[MP42AudioTrack class]]) {
                MP42AudioTrack *audioTrack = (MP42AudioTrack *)track;
                if (!isTrackMuxable(audioTrack.format) && trackNeedConversion(audioTrack.format)) {
                    MP42AudioConversionSettings *settings = [[MP42AudioConversionSettings alloc] initWithFormat:kMP42AudioCodecType_MPEG4AAC bitRate:(UInt32)audioBitrate mixDown:mixdown drc:drc];
                    audioTrack.conversionSettings = settings;
                }
                audioTrack.enabled = YES;
                [mp4 addTrack:audioTrack];
                [addedTracks addObject:audioTrack];
            } else if ([track isKindOfClass:[MP42SubtitleTrack class]] || [track isKindOfClass:[MP42ClosedCaptionTrack class]] || [track isKindOfClass:[MP42ChapterTrack class]]) {
                if (!isTrackMuxable(track.format) && trackNeedConversion(track.format)) {
                    MP42ConversionSettings *settings = [MP42ConversionSettings subtitlesConversion];
                    track.conversionSettings = settings;
                }
                [mp4 addTrack:track];
                [addedTracks addObject:track];
            } else {
                fprintf(stderr, "Skipping unsupported track %u\n", track.trackId);
            }
        }

        if (addedTracks.count == 0) {
            fprintf(stderr, "No compatible tracks found in input.\n");
            return 1;
        }

        NSMutableDictionary<NSString *, id> *options = [NSMutableDictionary dictionary];
        if (forceHvc1) {
            options[MP42ForceHvc1] = @YES;
        }

        if (mp4.dataSize > 3800000000ULL) {
            options[MP4264BitData] = @YES;
        }

        if (showProgress) {
            mp4.progressHandler = ^(double progress) {
                int percent = (int)round(progress * 100.0);
                fprintf(stderr, "\rMuxing... %3d%%", percent);
                fflush(stderr);
            };
        }

        BOOL success = [mp4 writeToUrl:outputURL options:options error:&error];

        if (showProgress) {
            fprintf(stderr, "\rMuxing... 100%%\n");
        }

        if (!success) {
            fprintf(stderr, "Failed to remux: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }

        if (optimize) {
            MP42File *optimizeFile = [[MP42File alloc] initWithURL:outputURL error:&error];
            if (!optimizeFile) {
                fprintf(stderr, "Warning: unable to reopen output for optimization: %s\n", error.localizedDescription.UTF8String);
            } else {
                if (![optimizeFile optimize]) {
                    fprintf(stderr, "Warning: optimization failed.\n");
                }
            }
        }

        fprintf(stdout, "Output written to %s\n", outputURL.path.UTF8String);

        return 0;
    }
}
