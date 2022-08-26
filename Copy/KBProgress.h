#import <Foundation/Foundation.h>

@class KBProgress;

NS_ASSUME_NONNULL_BEGIN

KBProgress * KBMakeProgress(double elapsedTime, double totalTime, double speed, NSString * _Nullable processingFile);

@interface KBProgress: NSObject

@property double elapsedTime;
@property double totalTime;
@property double speed;
@property NSDate *start;
@property (nonatomic, strong) NSString *processingFile;
- (double)calculatedRemainingTime;
- (NSProgress *)progressRepresentation;
@end

NS_ASSUME_NONNULL_END
