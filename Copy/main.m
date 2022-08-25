//
//  main.m
//
//  Created by Doug Russell on 2/12/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSTLCopyOperation.h"
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

#define OPTION_FLAGS "fvq"
char *progname;
char *dname;
bool quiet;

static struct option longopts[] = {

    { "force",                      no_argument, NULL,   'f' },
    { "verbose",                    no_argument, NULL,   'v' },
    { "quiet",                      no_argument, NULL,   'q' },
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

// A nice loading bar. Credits: classdump-dyld
static inline void loadBar(off_t currentValue, off_t totalValue, NSInteger remaining, int width, const char *fileName) {
    // Calculuate the ratio of complete-to-incomplete.
    if (quiet) return;
    float ratio = currentValue/(float)totalValue;
    int   elapsed     = ratio * width;
    NSString *rem = @"";
    NSString *det = @"";
    // Show the percentage complete.
    printf("%3d%% [", (int)(ratio*100));
    
    // Show the load bar.
    for (int x=0; x<elapsed; x++)
        printf("=");
    
    for (int x=elapsed; x<width; x++)
        printf(" ");
    
    if (remaining != 0) {
        rem = [[NSString stringWithFormat:@"%lu",remaining] TIMEFormat];
        det = BYTE_PROGRESS(currentValue, totalValue);
    }
    
    // ANSI Control codes to go back to the
    // previous line and clear it.
    printf("] %s %s <%s> \n\033[F\033[J",[rem UTF8String], [det UTF8String], fileName);
}

void usage() {
    
    printf("usage: %s -f [-vq] source_file target_file\n", [[[NSProcessInfo processInfo] processName] UTF8String]);
    exit(0);
}

int main(int argc, char * argv[]) {
    BOOL verbose = false;
    BOOL force = false;
    int flag;
    NSString *myOpts = @"";
    while ((flag = getopt_long(argc, argv, OPTION_FLAGS, longopts, NULL)) != -1) {
        switch(flag) {
            case 'f':
                force = true;
                myOpts = [myOpts stringByAppendingString:@"f"];
                break;
            case 'v':
                verbose = true;
                quiet = false;
                myOpts = [myOpts stringByReplacingOccurrencesOfString:@"q" withString:@""];
                myOpts = [myOpts stringByAppendingString:@"v"];
                break;
            case 'q':
                quiet = true;
                verbose = false;
                myOpts = [myOpts stringByReplacingOccurrencesOfString:@"v" withString:@""];
                myOpts = [myOpts stringByAppendingString:@"q"];
                break;
        }
    }
    argc -= optind;
    argv += optind;
    if (argc == 2){
        NSString *fromPath = [NSString stringWithUTF8String:argv[0]];
        NSString *toPath = [NSString stringWithUTF8String:argv[1]];
        if ([toPath isEqualToString:@"."]) {
            toPath = [fromPath lastPathComponent];
        }
        RSTLCopyOperation *copyOperation = [[RSTLCopyOperation alloc] initWithInputFile:fromPath toPath:toPath];
        copyOperation.force = force;
        copyOperation.verbose = verbose;
        copyOperation.progressBlock = ^(KBProgress *progress) {
            //NSLog(@"%lu/%lu", elapsedValue, totalSize);
            loadBar(progress.elapsedTime, progress.totalTime, progress.calculatedRemainingTime, 50, [[progress processingFile] UTF8String]);//[[toPath lastPathComponent] UTF8String]);
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

