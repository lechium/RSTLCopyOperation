//
//  RSTLCopyOperation.h
//
//  Created by Doug Russell on 2/12/13.
//  Updated By Kevin Bradley in 2022
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

#import <Foundation/Foundation.h>
#import "KBProgress.h"
#include <libgen.h>

// Disclaimer: This implementation was mostly just a tinker toy.
// Copyfile is theoretically the replacement for the FS API that let you do copy operations and get progress callbacks,
// (https://developer.apple.com/library/mac/documentation/Carbon/Reference/File_Manager/DeprecationAppendix/AppendixADeprecatedAPI.html#//apple_ref/c/func/FSCopyObjectAsync)
// but it still has this in the header:

/*
 * This API facilitates the copying of files and their associated
 * metadata.  There are several open source projects that need
 * modifications to support preserving extended attributes and ACLs
 * and this API collapses several hundred lines of modifications into
 * one or two calls.
 */

// The header has been updated as such - I think its much safer now to use these API's

typedef NS_ENUM(int8_t, RSTLCopyState) {
    RSTLCopyNotStarted,
    RSTLCopyInProgress,
    RSTLCopyFinished,
	RSTLCopyFailed,
};

@protocol RSTLCopyOperationDelegate;

@interface RSTLCopyOperation : NSOperation

@property BOOL verbose;
@property BOOL force;
@property BOOL quiet;
@property BOOL safe;
@property BOOL move;
@property BOOL clone;
@property (copy, nonatomic, readonly) NSString *fromPath;
@property (copy, nonatomic, readonly) NSString *toPath;
@property (nonatomic, copy) void (^progressBlock)(KBProgress *progress);
@property (nonatomic, copy) void (^stageChanged)(NSInteger stage, NSInteger what);
@property (nonatomic, copy) void (^stateChanged)(RSTLCopyState state, NSInteger resultCode);

@property (readonly) RSTLCopyState state;
// Not valid until operation has finished
@property (readonly) int resultCode;

- (instancetype)initWithInputFile:(NSString *)fromPath toPath:(NSString *)toPath;
+ (void)logLevel:(NSInteger)level string:(NSString *)string;
+ (void)logLevel:(NSInteger)level stringWithFormat:(NSString *)fmt, ...;
+ (NSInteger)width;
@end

