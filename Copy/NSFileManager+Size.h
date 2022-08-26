@interface NSFileManager(Util)
+ (NSUInteger)sizeForFolderAtPath:(NSString *)source;
+ (CGFloat)availableSpaceForPath:(NSString *)source;
@end
