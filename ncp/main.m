//
//  main.m
//
//  Created by Doug Russell on 2/12/13.
//  Updated By Kevin Bradley in 2022
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSTLCopyOperation.h"
#import "NSFileManager+Size.h"
#ifdef __APPLE__
#include <sys/syslimits.h>
#endif

#include <stdio.h>
#include <errno.h>
#include <libgen.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>

#define OPTION_FLAGS "fvqsmcd:"
char *progname;
char *dname;
bool quiet;

static struct option longopts[] = {

    { "force",                      no_argument, NULL,   'f' },
    { "verbose",                    no_argument, NULL,   'v' },
    { "quiet",                      no_argument, NULL,   'q' },
    { "safe",                       no_argument, NULL,   's' },
    { "move",                       no_argument, NULL,   'm' },
    { "clone",                      no_argument, NULL,   'c' },
    { "directory-size",             required_argument, NULL, 'd'},
    { NULL,                         0, NULL,   0 }
};


@interface NSString (extras)
- (NSString *)TIMEFormat;
@end

@implementation NSString (extras)

- (NSString *)TIMEFormat {
    
    NSInteger interval = [self doubleValue];
    long seconds = interval % 60;
    long minutes = (interval / 60) % 60;
    long hours = (interval / 3600);
    return [NSString stringWithFormat:@"[%0.2ld:%0.2ld:%0.2ld]", hours, minutes, seconds];
}

@end

static inline int barWidth(KBProgress *progress, int width, NSInteger screenWidth) {
    float ratio = progress.elapsedTime/(float)progress.totalTime;
    int   elapsed     = ratio * width;
    int remain = width - elapsed;
    NSString *rem = @"";
    NSString *det = @"";
    NSString *fc = @"";
    NSInteger percentSize = 11; // %XX [
    NSInteger nameBrackets = 2; // <>
    NSInteger filenameLength = [progress processingFile].length;
    NSInteger stringLength = remain + percentSize + elapsed + nameBrackets + filenameLength;
    if (progress.calculatedRemainingTime != 0) { //@"[00:00:00]"
        rem = [[NSString stringWithFormat:@"%f",progress.calculatedRemainingTime] TIMEFormat];
        det = BYTE_PROGRESS(progress.elapsedTime, progress.totalTime);
        stringLength+= rem.length; //should always be 10
        stringLength+= det.length;
        if (progress.totalCount > 1){
            fc = [NSString stringWithFormat:@"%lu/%lu", progress.processedCount+1, progress.totalCount];
            stringLength+= fc.length;
        }
    }
    //printf("length: %lu width: %lu rem: %lu det: %lu\n", stringLength, screenWidth, rem.length, det.length);
    if (stringLength > screenWidth) {
        NSInteger diff = stringLength - screenWidth;
        NSInteger newWidth = width - diff;
        //printf("%lu > %lu diff = %lu nw: %lu\n", stringLength, screenWidth, diff, newWidth);
        return (int)newWidth;
    }
    return width;
}

// A nice loading bar. Credits: classdump-dyld

static inline void loadBar(KBProgress *progress, int width, NSInteger screenwidth) {
    // Calculuate the ratio of complete-to-incomplete.
    if (quiet) return;
    float ratio = progress.elapsedTime/(float)progress.totalTime;
    //float ratio = currentValue/(float)totalValue;
    int   elapsed     = ratio * width;
    NSString *rem = @"";
    NSString *det = @"";
    NSString *fc = @"";
    if (progress.calculatedRemainingTime != 0) { //@"[00:00:00]"
        rem = [[NSString stringWithFormat:@"%f",progress.calculatedRemainingTime] TIMEFormat];
        det = BYTE_PROGRESS(progress.elapsedTime, progress.totalTime);
        if (progress.totalCount > 1){
            fc = [NSString stringWithFormat:@"%lu/%lu", progress.processedCount, progress.totalCount];
        }
    }
    
    // Show the percentage complete.
    printf("%3d%% [", (int)(ratio*100));
    
    // Show the load bar.
    for (int x=0; x<elapsed; x++) {
        printf("=");
    }
    
    for (int x=elapsed; x<width; x++) {
        printf(" ");
    }
    
    // ANSI Control codes to go back to the
    // previous line and clear it.
    printf("] %s %s %s <%s> \n\033[F\033[J",[rem UTF8String], [det UTF8String], [fc UTF8String], [[progress processingFile] UTF8String]);
}

void usage() {
    
    printf("usage: %s -f -s [-vq] source_file target_file\n", [[[NSProcessInfo processInfo] processName] UTF8String]);
    exit(0);
}

int main(int argc, char * argv[]) {
    BOOL verbose = false;
    BOOL force = false;
    BOOL safe = false;
    BOOL move = false;
    BOOL clone = false;
    NSString *dSizeFolder = nil;
    int flag;
    NSInteger width = [RSTLCopyOperation width];
    while ((flag = getopt_long(argc, argv, OPTION_FLAGS, longopts, NULL)) != -1) {
        switch(flag) {
            case 'd':
                dSizeFolder = [NSString stringWithUTF8String:optarg];
                break;
            case 'f':
                force = true;
                break;
            case 'v':
                verbose = true;
                quiet = false;
                break;
            case 'q':
                quiet = true;
                verbose = false;
                break;
            case 's':
                safe = true;
                break;
            case 'm':
                move = true;
                break;
            case 'c':
                clone = true;
                break;
        }
    }
    argc -= optind;
    argv += optind;
    if (dSizeFolder) {
        NSString *output = FANCY_BYTES([NSFileManager sizeForFolderAtPath:dSizeFolder]);
        DLog(@"%@: %@", dSizeFolder, output);
        return 0;
    }
    if (argc == 2){
        NSString *fromPath = [NSString stringWithUTF8String:argv[0]];
        NSString *toPath = [NSString stringWithUTF8String:argv[1]];
        RSTLCopyOperation *copyOperation = [[RSTLCopyOperation alloc] initWithInputFile:fromPath toPath:toPath];
        copyOperation.force = force;
        copyOperation.safe = safe;
        copyOperation.verbose = verbose;
        copyOperation.move = move;
        copyOperation.clone = clone;
        //DLog(@"width: %lu", width);
        __block int calcBarWidth = 0;
        copyOperation.progressBlock = ^(KBProgress *progress) {
            //NSLog(@"%lu/%lu", elapsedValue, totalSize);
            int barSize = 50;
            if (width < 100){
                barSize = 30;
            }
            if (calcBarWidth == 0){
                calcBarWidth = barWidth(progress, barSize, width);
                //DLog(@"calcBarWidth: %lu", calcBarWidth);
                loadBar(progress, calcBarWidth, width);
            } else {
                loadBar(progress, calcBarWidth, width);
            }
        };
        copyOperation.stateChanged = ^(RSTLCopyState state, NSInteger resultCode) {
            //NSLog(@"state changed: %hhd code: %lu", state, resultCode);
            switch (state) {
                case RSTLCopyNotStarted:
                    break;
                    
                case RSTLCopyFailed:
                    break;
                    
                case RSTLCopyFinished:
                    break;
                    
                case RSTLCopyInProgress:
                    break;
                default:
                    break;
            }
        };
        NSOperationQueue *queue = [NSOperationQueue new];
        [queue cancelAllOperations];
        [queue addOperation:copyOperation];
        if (![copyOperation isExecuting]){
            //NSLog(@"is NOT executing... kickstart!");
            //[copyOperation main];
        }
        [queue waitUntilAllOperationsAreFinished];
        return copyOperation.resultCode;
    } else {
        usage();
    }
    return 0;
}

