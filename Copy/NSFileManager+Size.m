
#import "NSFileManager+Size.h"
#include <sys/stat.h>
#import "RSTLCopyOperation.h"
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
@implementation NSFileManager(Util)

long long do_ls(const char *name, int returnType) {
    DIR *dir_ptr;
    struct dirent *direntp;
    struct stat info;
    long long total = 0;
    int fileCount = 0;
    if (stat(name, &info)) {
        fprintf(stderr, "ls01: cannot stat %s\n", name);
        return 0;
    }
    if (S_ISDIR(info.st_mode)) {
        if ((dir_ptr = opendir(name)) == NULL) {
            fprintf(stderr, "ls01: cannot open directory %s\n", name);
        } else {
            while ((direntp = readdir(dir_ptr)) != NULL) {
                char *pathname;

                /* ignore current and parent directories */
                if (!strcmp(direntp->d_name, ".") || !strcmp(direntp->d_name, ".."))
                    continue;

                pathname = malloc(strlen(name) + 1 + strlen(direntp->d_name) + 1);
                if (pathname == NULL) {
                    fprintf(stderr, "ls01: cannot allocated memory\n");
                    exit(1);
                }
                sprintf(pathname, "%s/%s", name, direntp->d_name);
                if (returnType == 0) {
                    total += do_ls(pathname, returnType);
                } else if (returnType == 1) {
                    fileCount+= do_ls(pathname, returnType);
                }
                free(pathname);
            }
            closedir(dir_ptr);
        }
    } else {
        total = info.st_size;
        fileCount++;
    }
    //printf("file count: %i\n", fileCount);
    //printf("%10lld  %s\n", total, name);
    if (returnType == 0) {
        return total;
    } else if (returnType == 1){
        return fileCount;
    }
    return total;
}

+ (void)ls:(const char *)name completion:(void(^)(NSInteger size, NSInteger count))block {
    DIR *dir_ptr;
    struct dirent *direntp;
    struct stat info;
    __block long long total = 0;
    __block int fileCount = 0;
    if (stat(name, &info)) {
        fprintf(stderr, "ls01: cannot stat %s\n", name);
        return;
    }
    if (S_ISDIR(info.st_mode)) {
        if ((dir_ptr = opendir(name)) == NULL) {
            fprintf(stderr, "ls01: cannot open directory %s\n", name);
        } else {
            while ((direntp = readdir(dir_ptr)) != NULL) {
                char *pathname;

                /* ignore current and parent directories */
                if (!strcmp(direntp->d_name, ".") || !strcmp(direntp->d_name, ".."))
                    continue;

                pathname = malloc(strlen(name) + 1 + strlen(direntp->d_name) + 1);
                if (pathname == NULL) {
                    fprintf(stderr, "ls01: cannot allocate memory\n");
                    exit(1);
                }
                sprintf(pathname, "%s/%s", name, direntp->d_name);
                [self ls:pathname completion:^(NSInteger size, NSInteger count) {
                    total+=size;
                    fileCount+=count;
                }];
                free(pathname);
            }
            closedir(dir_ptr);
        }
    } else {
        total = info.st_size;
        fileCount++;
    }
    //printf("file count: %i\n", fileCount);
    //printf("%10lld  %s\n", total, name);
    if (block) {
        block(total,fileCount);
    }
}



+ (NSUInteger)sizeForFolderAtPath:(NSString *)source {
    return do_ls([source UTF8String], 0);
}

+ (NSUInteger)countForFolderAtPath:(NSString *)source {
    return do_ls([source UTF8String], 1);
}


+ (CGFloat)availableSpaceForPath:(NSString *)source {
    return [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:source error:nil]objectForKey:NSFileSystemFreeSize] floatValue];
}

@end
