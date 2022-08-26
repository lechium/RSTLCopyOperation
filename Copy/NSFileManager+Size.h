@interface NSFileManager(Util)
+ (NSUInteger)sizeForFolderAtPath:(NSString *)source;
+ (CGFloat)availableSpaceForPath:(NSString *)source;
+ (void)asyncSizeForItemAtPath:(NSString *)source completion:(void(^)(NSUInteger size))block;
+ (void)asyncCountForItemAtPath:(NSString *)source completion:(void(^)(NSUInteger count))block;
- (void)ls:(const char *)name completion:(void(^)(NSInteger size, NSInteger count))block;
@end
