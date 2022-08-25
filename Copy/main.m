//
//  main.m
//
//  Created by Doug Russell on 2/12/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSTLCopyOperation.h"

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
static inline void loadBar(off_t currentValue, off_t totalValue, NSInteger remaining, NSString *details, int width, const char *fileName) {
    // Calculuate the ratio of complete-to-incomplete.
    float ratio = currentValue/(float)totalValue;
    int   elapsed     = ratio * width;
    NSString *rem = @"";
    // Show the percentage complete.
    printf("%3d%% [", (int)(ratio*100));
    
    // Show the load bar.
    for (int x=0; x<elapsed; x++)
        printf("=");
    
    for (int x=elapsed; x<width; x++)
        printf(" ");
    
    if (remaining != 0) {
        rem = [[NSString stringWithFormat:@"%lu",remaining] TIMEFormat];
    }
    
    // ANSI Control codes to go back to the
    // previous line and clear it.
    printf("] %s %s <%s> \n\033[F\033[J",[rem UTF8String], [details UTF8String], fileName);
}

int main(int argc, const char * argv[]) {
    if (argc >= 3){
        NSString *fromPath = [NSString stringWithUTF8String:argv[1]];
        NSString *toPath = [NSString stringWithUTF8String:argv[2]];
        if ([toPath isEqualToString:@"."]) {
            toPath = [fromPath lastPathComponent];
        }
        RSTLCopyOperation *copyOperation = [[RSTLCopyOperation alloc] initWithFromPath:fromPath toPath:toPath];
        copyOperation.progressBlock = ^(NSInteger elapsedValue, NSInteger totalSize, NSInteger remainingTime, NSString *details) {
            //NSLog(@"%lu/%lu", elapsedValue, totalSize);
            loadBar(elapsedValue, totalSize, remainingTime, details, 50, [[toPath lastPathComponent] UTF8String]);
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
            [copyOperation main];
        }
        [queue waitUntilAllOperationsAreFinished];
        return copyOperation.resultCode;
    }
    return 0;
}

