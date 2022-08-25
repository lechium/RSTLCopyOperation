@interface NSFileManager(Util)
- (NSNumber *)sizeForFolderAtPath:(NSString *)source error:(NSError **)error;
+ (NSUInteger)sizeForFolderAtPath:(NSString *)source;
@end
