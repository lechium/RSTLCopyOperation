
#import "NSFileManager+Size.h"
#include <sys/stat.h>

@implementation NSFileManager(Util)

+ (NSUInteger)sizeForFolderAtPath:(NSString *)source {
    NSArray * contents = nil;
    NSUInteger size = 0;
    NSEnumerator * enumerator = nil;
    NSString * path = nil;
    BOOL isDirectory = false;
    NSFileManager *fm = [NSFileManager defaultManager];
    // Determine Paths to Add
    if ([fm fileExistsAtPath:source isDirectory:&isDirectory] && isDirectory) {
        contents = [fm subpathsAtPath:source];
    } else {
        contents = [NSArray array];
    }
    // Add Size Of All Paths
    enumerator = [contents objectEnumerator];
    while (path = [enumerator nextObject]) {
        NSString *currentFile = [source stringByAppendingPathComponent:path];
        struct stat st;
        if (stat([currentFile UTF8String], &st) == 0) {
            size += st.st_size;
        }
    }
    return size;
}

- (NSNumber *)sizeForFolderAtPath:(NSString *) source error:(NSError **)error {
    NSArray * contents = nil;
    unsigned long long size = 0;
    NSEnumerator * enumerator = nil;
    NSString * path = nil;
    BOOL isDirectory = false;
    
    // Determine Paths to Add
    if ([self fileExistsAtPath:source isDirectory:&isDirectory] && isDirectory) {
        contents = [self subpathsAtPath:source];
    } else {
        contents = [NSArray array];
    }
    // Add Size Of All Paths
    enumerator = [contents objectEnumerator];
    while (path = [enumerator nextObject]) {
        NSString *currentFile = [source stringByAppendingPathComponent:path];
        struct stat st;
        if (stat([currentFile UTF8String], &st) == 0) {
            //return st.st_size;
            size += st.st_size;
        }
        //NSDictionary * fattrs = [self attributesOfItemAtPath: [ source stringByAppendingPathComponent:path ] error:error];
        //size += [[fattrs objectForKey:NSFileSize] unsignedLongLongValue];
    }
    // Return Total Size in MB
    
    return [NSNumber numberWithUnsignedLongLong:size/1024/1024];
}

@end
