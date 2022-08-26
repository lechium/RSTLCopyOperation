
#import "NSFileManager+Size.h"
#include <sys/stat.h>
#import "RSTLCopyOperation.h"

@implementation NSFileManager(Util)

+ (NSUInteger)sizeForFolderAtPath:(NSString *)source {
    LOG_SELF;
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
        //VerboseLog(@"processing file: %@", currentFile);
        struct stat st;
        if (stat([currentFile UTF8String], &st) == 0) {
            size += st.st_size;
        }
    }
    return size;
}

+ (CGFloat)availableSpaceForPath:(NSString *)source {
    return [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:source error:nil]objectForKey:NSFileSystemFreeSize] floatValue];
}

@end
