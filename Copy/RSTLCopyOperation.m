//
//  RSTLCopyOperation.m
//
//  Created by Doug Russell on 2/12/13.
//  Copyright (c) 2013 Doug Russell. All rights reserved.
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//  http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//  

#define ALog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__])
#define DLog(format, ...) ALog(@"[Copy] %@", [NSString stringWithFormat:format, ## __VA_ARGS__])
#define LOG_SELF        ALog(@"[Copy] %@ %@", self, NSStringFromSelector(_cmd))


#import "RSTLCopyOperation.h"
#include "copyfile.h"
#include <sys/stat.h>

off_t fsize(const char *filename) {
    struct stat st;
    if (stat(filename, &st) == 0) {
        return st.st_size;
    }
    return -1;
}

@interface RSTLCopyOperation (){
    BOOL _finished;
    BOOL _executing;
    RSTLCopyState _state;
}

@property RSTLCopyState state;
@property int resultCode;
@property NSUInteger currentFileSize;
@property NSDate *start;

@end

@implementation RSTLCopyOperation

- (RSTLCopyState)state {
    return _state;
}

- (void)setState:(RSTLCopyState)state {
    _state = state;
    if (self.stateChanged) {
        self.stateChanged(state, self.resultCode);
    }
}

- (BOOL)isFinished {
    return _finished;
}

- (BOOL)isExecuting {
    return _executing;
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (instancetype)initWithFromPath:(NSString *)fromPath toPath:(NSString *)toPath {
    self = [super init];
    if (self) {
        _fromPath = [fromPath copy];
        _toPath = [toPath copy];
        _currentFileSize = fsize([_fromPath UTF8String]);
        //DLog(@"_currentFileSize: %lu", (unsigned long)_currentFileSize);
    }
    return self;
}

static int RSTLCopyFileCallback(int what, int stage, copyfile_state_t state, const char *fromPath, const char *toPath, void *context) {
    RSTLCopyOperation *self = (__bridge RSTLCopyOperation *)context;
    if ([self isCancelled]) {
        DLog(@"isCancelled");
        return COPYFILE_QUIT;
    }
    if (self.stageChanged) {
        self.stageChanged(stage, what);
    }
    switch (what) {
        case COPYFILE_RECURSE_FILE:
            switch (stage) {
                case COPYFILE_START:
                    NSLog(@"File Start");
                    break;
                case COPYFILE_FINISH:
                    NSLog(@"File Finish");
                    break;
                case COPYFILE_ERR:
                    NSLog(@"File Error %i", errno);
                    break;
            }
            break;
        case COPYFILE_RECURSE_DIR:
            switch (stage) {
                case COPYFILE_START:
                    NSLog(@"Dir Start");
                    break;
                case COPYFILE_FINISH:
                    NSLog(@"Dir Finish");
                    break;
                case COPYFILE_ERR:
                    NSLog(@"Dir Error");
                    break;
            }
            break;
        case COPYFILE_RECURSE_DIR_CLEANUP:
            switch (stage) {
                case COPYFILE_START:
                    NSLog(@"Dir Cleanup Start");
                    break;
                case COPYFILE_FINISH:
                    NSLog(@"Dir Cleanup Finish");
                    break;
                case COPYFILE_ERR:
                    NSLog(@"Dir Cleanup Error");
                    break;
            }
            break;
        case COPYFILE_RECURSE_ERROR:
            
            break;
        case COPYFILE_COPY_XATTR:
            switch (stage) {
                case COPYFILE_START:
                    //NSLog(@"Xattr Start");
                    break;
                case COPYFILE_FINISH:
                    //NSLog(@"Xattr Finish");
                    break;
                case COPYFILE_ERR:
                    //NSLog(@"Xattr Error");
                    break;
            }
            break;
        case COPYFILE_COPY_DATA:
            switch (stage) {
                case COPYFILE_PROGRESS:
                {
                    off_t copiedBytes;
                    const int returnCode = copyfile_state_get(state, COPYFILE_STATE_COPIED, &copiedBytes);
                    double remainingTime = 0;
                    if (returnCode == 0) {
                        if (self.start == nil) {
                            //fprintf(stdout, "setting start date...\n");
                            self.start = [NSDate date];
                        } else {
                            NSTimeInterval sec = [[NSDate date] timeIntervalSinceDate:self.start];
                            double speed = copiedBytes/sec;
                            remainingTime = (self.currentFileSize - copiedBytes)/speed;
                            //fprintf(stdout, "remaining time: %f\n", remainingTime);
                        }
                        if (self.progressBlock) {
                            self.progressBlock(copiedBytes, self.currentFileSize, remainingTime);
                        } else {
                            NSLog(@"Copied %@ of %s so far", [NSByteCountFormatter stringFromByteCount:copiedBytes countStyle:NSByteCountFormatterCountStyleFile], fromPath);
                        }
                    } else {
                        NSLog(@"Could not retrieve copyfile state");
                    }
                    break;
                }
                case COPYFILE_ERR:
                    NSLog(@"Data Error");
                    break;
            }
            break;
    }
    return COPYFILE_CONTINUE;
    //return COPYFILE_SKIP;
    //return COPYFILE_QUIT;
}

- (int)flags {
    // TODO: Figure out why COPYFILE_EXCL doesn't work for directories
    // Probably need to do something in the callback
    int flags = COPYFILE_ALL|COPYFILE_NOFOLLOW|COPYFILE_EXCL;
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.fromPath isDirectory:&isDir] && isDir) {
        flags |= COPYFILE_RECURSIVE;
    }
    return flags;
}

- (void)main {
    [self setExecuting:true];
    [self setFinished:false];
    copyfile_state_t copyfileState = copyfile_state_alloc();
    
    const char *fromPath = [self.fromPath fileSystemRepresentation];
    const char *toPath = [self.toPath fileSystemRepresentation];
    
    self.state = RSTLCopyInProgress;
    
    copyfile_state_set(copyfileState, COPYFILE_STATE_STATUS_CB, &RSTLCopyFileCallback);
    copyfile_state_set(copyfileState, COPYFILE_STATE_STATUS_CTX, (__bridge void *)self);
    
    self.resultCode = copyfile(fromPath, toPath, copyfileState, [self flags]);
    
    self.state = (self.resultCode == 0) ? RSTLCopyFinished : RSTLCopyFailed;
    
    copyfile_state_free(copyfileState);

    [self setExecuting:false];
    [self setFinished:true];
    DLog(@"isFinished: %d", self.isFinished);
    
}

@end
