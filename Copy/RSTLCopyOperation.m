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

#import "RSTLCopyOperation.h"
#include "copyfile.h"
#include <sys/stat.h>
#import "NSFileManager+Size.h"

bool fileExists(const char* file) {
    struct stat buf;
    return (stat(file, &buf) == 0);
}

bool is_dir(const char *path) {
    struct stat s;
    return (stat(path, &s) == 0 && s.st_mode & S_IFDIR);
}

off_t fsize(const char *filename) {
    if (is_dir(filename)) {
        return [NSFileManager sizeForFolderAtPath:[NSString stringWithUTF8String:filename]];
    }
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
@property KBProgress *progress;

@end

@implementation RSTLCopyOperation

- (instancetype)initWithInputFile:(NSString *)fromPath toPath:(NSString *)toPath {
    self = [super init];
    if (self) {
        _fromPath = [fromPath copy];
        _toPath = [toPath copy];
        _currentFileSize = fsize([_fromPath UTF8String]);
        //DLog(@"_currentFileSize: %lu", (unsigned long)_currentFileSize);
        _progress = KBMakeProgress(0, _currentFileSize, 0, toPath);
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
                    self.progress.start = [NSDate date];
                    self.currentFileSize = fsize(fromPath);
                    self.progress.totalTime = self.currentFileSize;
                    if (fileExists(toPath)) {
                        //VerboseLog(@"File exists: %s", toPath);
                        off_t toSize = fsize(toPath);
                        off_t fromSize = fsize(fromPath);
                        if (toSize < fromSize) {
                            VerboseLog(@"Incomplete file size %@ vs %@\n", FANCY_BYTES(toSize), FANCY_BYTES(fromSize));
                            remove(toPath);
                        } else { // exists and size is equal to the expected size
                            if (self.verbose) {
                                if (self.force) {
                                    fprintf(stdout, "%s -> %s\n", fromPath, toPath);
                                    self.progress.processingFile = [NSString stringWithUTF8String:toPath];
                                    
                                } else {
                                    fprintf(stdout, "%s not overwritten\n", toPath);
                                    return COPYFILE_SKIP;
                                }
                            }
                        }
                    } else {
                        self.progress.processingFile = [NSString stringWithUTF8String:toPath];
                        if (self.verbose) fprintf(stdout, "%s -> %s\n", fromPath, toPath);
                    }
                    //VerboseLog(@"File Start %s size: %@\n", fromPath, FANCY_BYTES(self.currentFileSize));
                    break;
                case COPYFILE_FINISH:
                    //VerboseLog(@"File Finish");
                    break;
                case COPYFILE_ERR:
                    VerboseLog(@"File Error %i", errno);
                    break;
            }
            break;
        case COPYFILE_RECURSE_DIR:
            switch (stage) {
                case COPYFILE_START:
                    //VerboseLog(@"Dir Start: %s size: %@", toPath, FANCY_BYTES(fsize(fromPath)));
                    if (self.verbose) fprintf(stdout, "%s -> %s\n", fromPath, toPath);
                    break;
                case COPYFILE_FINISH:
                    //VerboseLog(@"Dir Finish: %s", toPath);
                    break;
                case COPYFILE_ERR:
                    //VerboseLog(@"Dir Error: %s", toPath);
                    break;
            }
            break;
        case COPYFILE_RECURSE_DIR_CLEANUP:
            switch (stage) {
                case COPYFILE_START:
                    //VerboseLog(@"Dir Cleanup Start");
                    break;
                case COPYFILE_FINISH:
                    //VerboseLog(@"Dir Cleanup Finish");
                    break;
                case COPYFILE_ERR:
                    //VerboseLog(@"Dir Cleanup Error");
                    break;
            }
            break;
        case COPYFILE_RECURSE_ERROR:
            
            break;
        case COPYFILE_COPY_XATTR:
            switch (stage) {
                case COPYFILE_START:
                    //VerboseLog(@"Xattr Start");
                    break;
                case COPYFILE_FINISH:
                    //VerboseLog(@"Xattr Finish");
                    break;
                case COPYFILE_ERR:
                    //VerboseLog(@"Xattr Error");
                    break;
            }
            break;
        case COPYFILE_COPY_DATA:
            switch (stage) {
                case COPYFILE_PROGRESS:
                {
                    off_t copiedBytes;
                    const int returnCode = copyfile_state_get(state, COPYFILE_STATE_COPIED, &copiedBytes);
                    if (returnCode == 0) {
                        if (self.progress.start == nil) {
                            //fprintf(stdout, "setting start date...\n");
                            self.progress.start = [NSDate date];
                        } else {
                            self.progress.elapsedTime = copiedBytes;
                        }
                        if (self.progressBlock) {
                            self.progressBlock(self.progress);
                        } else {
                            NSLog(@"Copied %@ of %s so far", FANCY_BYTES(copiedBytes), fromPath);
                        }
                    } else {
                        NSLog(@"Could not retrieve copyfile state");
                    }
                    break;
                }
                case COPYFILE_ERR:
                    VerboseLog(@"Data Error");
                    break;
            }
            break;
    }
    return COPYFILE_CONTINUE;
    //return COPYFILE_SKIP;
    //return COPYFILE_QUIT;
}

- (int)flags {
    int flags = COPYFILE_ALL|COPYFILE_NOFOLLOW|COPYFILE_EXCL;
    if (self.force) {
        flags &= ~COPYFILE_EXCL;
    }
    if (is_dir([self.fromPath UTF8String])) {
        flags |= COPYFILE_RECURSIVE;
    }
    return flags;
}

- (void)main {
    [self setExecuting:true];
    [self setFinished:false];
    copyfile_state_t copyfileState = copyfile_state_alloc();
    
    if (fileExists([_toPath UTF8String]) && !is_dir([_toPath UTF8String])) {
        VerboseLog(@"%@ not overwritten", _toPath);
        off_t toSize = fsize([_toPath UTF8String]);
        off_t fromSize = fsize([_fromPath UTF8String]);
        VerboseLog(@"Compare sizes %@ vs %@\n", FANCY_BYTES(toSize), FANCY_BYTES(fromSize));
    }
    
    const char *fromPath = [self.fromPath fileSystemRepresentation];
    const char *toPath = [self.toPath fileSystemRepresentation];
    if (self.verbose)fprintf(stdout, "%s -> %s\n", fromPath, toPath);
    if (is_dir(fromPath)) {
        VerboseLog(@"%s size: %@", fromPath, FANCY_BYTES(fsize(fromPath)));
    }
    self.state = RSTLCopyInProgress;
    copyfile_state_set(copyfileState, COPYFILE_STATE_STATUS_CB, &RSTLCopyFileCallback);
    copyfile_state_set(copyfileState, COPYFILE_STATE_STATUS_CTX, (__bridge void *)self);
    self.resultCode = copyfile(fromPath, toPath, copyfileState, [self flags]);
    self.state = (self.resultCode == 0) ? RSTLCopyFinished : RSTLCopyFailed;
    copyfile_state_free(copyfileState);
    fprintf(stdout,"\nCopied %s from %s to %s\n", [FANCY_BYTES(fsize([_toPath UTF8String])) UTF8String], [_fromPath UTF8String], [_toPath UTF8String]);
    [self setExecuting:false];
    [self setFinished:true];
}

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

+ (BOOL)isVerbose {
    BOOL vb = [[NSUserDefaults standardUserDefaults] boolForKey:@"verbose"];
    //DLog(@"vb: %d, contains: %d",vb, [[[NSProcessInfo processInfo] arguments] containsObject:@"-v"] );
    return vb || [[[NSProcessInfo processInfo] arguments] containsObject:@"-v"];
}

+ (void)logLevel:(NSInteger)level string:(NSString *)string {
    if (level == 0 || [self isVerbose]){ //info level
        DLog(@"%@", string);
    } else {
        if ([self isVerbose]){
            DLog(@"%@", string);
        }
    }
}

+ (void)logLevel:(NSInteger)level stringWithFormat:(NSString *)fmt, ... {
    //DLog(@"logLevel: %lu", level);
    //return;
    va_list args;
    va_start(args, fmt);
    va_end(args);
    //NSString *output = [[NSString alloc] initWithFormat:fmt arguments:args];
    //DLog(@"we made a output: %@", output);
    if (level == 0){ //info level
        DLog(fmt, args);
    } else {
        if ([self isVerbose]){
            DLog(fmt, args);
        }
    }
}

@end
