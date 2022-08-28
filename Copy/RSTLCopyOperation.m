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
@property NSUInteger initialFileSize;
@property NSInteger fileCount;
@property NSInteger processedFiles;
@property KBProgress *progress;

@end

@implementation RSTLCopyOperation

- (instancetype)initWithInputFile:(NSString *)fromPath toPath:(NSString *)toPath {
    self = [super init];
    if (self) {
        _fromPath = [fromPath copy];
        _toPath = [toPath copy];
        if (!is_dir([fromPath UTF8String]) && [self.toPath isEqualToString:@"."]){
            _toPath = [_fromPath lastPathComponent];
        }
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
                    self.progress.start = [NSDate date];
                    self.currentFileSize = fsize(fromPath);
                    self.progress.totalTime = self.currentFileSize;
                    if (fileExists(toPath)) {
                        //VerboseLog(@"File exists: %s", toPath);
                        off_t toSize = fsize(toPath);
                        off_t fromSize = self.currentFileSize;
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
                    self.processedFiles++;
                    self.progress.processedCount = self.processedFiles;
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
                    //VerboseLog(@"Dir Start: %s size: %@", toPath, FANCY_BYTES(_currentFileSize));
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

- (void)fail {
    
    self.resultCode = -1;
    self.state = RSTLCopyFailed;
    [self setExecuting:false];
    [self setFinished:true];
}

- (void)main {
    [self setExecuting:true];
    [self setFinished:false];
    BOOL isDir = (is_dir([_fromPath UTF8String]));
    if (isDir) {
        NSDate *start = [NSDate date];
        [NSFileManager ls:[_fromPath UTF8String] completion:^(NSInteger size, NSInteger count) {
            NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:start];
            VerboseLog(@"Fetched folder size: %@ with file count: %lu in %f seconds", FANCY_BYTES(size), count, interval);
            _initialFileSize = size;
            _fileCount = count;
            if (self.safe) {
                [self makingCopies];
            }
        }];
       
    } else { //isnt dir
        _currentFileSize = fsize([_fromPath UTF8String]);
        _initialFileSize = _currentFileSize;
        _fileCount = 1;
        if (self.safe) {
            [self makingCopies];
            return;
        }
    }
    if (!self.safe){
        [self makingCopies];
    }
}

+ (void)boldify {
    system("tput bold");
}

+ (void)revertBold {
    system("tput sgr0");
}

- (void)makingCopies {
    _progress = KBMakeProgress(0, _currentFileSize, 0, _toPath);
    _progress.totalCount = _fileCount;
    CGFloat availableSpace = [NSFileManager availableSpaceForPath:self.toPath];
    off_t fromSize = _initialFileSize;
    if (fromSize > availableSpace) {
        [RSTLCopyOperation boldify];
        InfoLog(@"\nThere isnt enough free space available to continue with this copy. %@ is required and %@ is available.\n\n", FANCY_BYTES(fromSize), FANCY_BYTES(availableSpace));
        [RSTLCopyOperation revertBold];
        [self fail];
        return;
    }
    CGFloat spaceAfter = availableSpace - fromSize; //the amount of space left after the copy is complete
    if (fileExists([_toPath UTF8String]) && !is_dir([_toPath UTF8String]) && !self.force) {
        VerboseLog(@"%@ not overwritten", _toPath);
        off_t toSize = fsize([_toPath UTF8String]);
        VerboseLog(@"Compare sizes %@ vs %@\n", FANCY_BYTES(toSize), FANCY_BYTES(fromSize));
        if (toSize != fromSize){
            VerboseLog(@"size mismatch, maybe force overwrite?");
        }
        [self fail];
        return;
    }
    copyfile_state_t copyfileState = copyfile_state_alloc();
    const char *fromPath = [self.fromPath fileSystemRepresentation];
    const char *toPath = [self.toPath fileSystemRepresentation];
    VerboseLog(@"\n%s size: %@", fromPath, FANCY_BYTES(_currentFileSize));
    if (self.verbose) {
        fprintf(stderr,"%s AvailableSpace: %s\n", toPath, [FANCY_BYTES(availableSpace) UTF8String]);
        fprintf(stdout, "Space After copy: %s\n---------------------\n\n", [FANCY_BYTES(spaceAfter) UTF8String]);
    }
    if (self.verbose)fprintf(stdout, "%s -> %s\n", fromPath, toPath);
    self.state = RSTLCopyInProgress;
    copyfile_state_set(copyfileState, COPYFILE_STATE_STATUS_CB, &RSTLCopyFileCallback);
    copyfile_state_set(copyfileState, COPYFILE_STATE_STATUS_CTX, (__bridge void *)self);
    self.resultCode = copyfile(fromPath, toPath, copyfileState, [self flags]);
    self.state = (self.resultCode == 0) ? RSTLCopyFinished : RSTLCopyFailed;
    copyfile_state_free(copyfileState);
    if (self.verbose) {
        if (self.fileCount > 0) {
            fprintf(stdout,"\nCopied %s in %li files from %s to %s\n\n", [FANCY_BYTES(_initialFileSize) UTF8String], self.fileCount, [_fromPath UTF8String], [_toPath UTF8String]);
        } else {
            fprintf(stdout,"\nCopied %s from %s to %s\n\n", [FANCY_BYTES(_initialFileSize) UTF8String], [_fromPath UTF8String], [_toPath UTF8String]);
        }
    }
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
    if (level == 0 || [self isVerbose]){
        DLog(@"%@", string);
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

+ (NSInteger)width {
    return [[self runCommand:@"tput cols"] integerValue];
}

+ (NSString *)runCommand:(NSString *)call {
    if (call==nil)
        return 0;
    char line[200];
    //DLog(@"running process: %@", call);
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp) {
        while (fgets(line, sizeof line, fp)) {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

@end
