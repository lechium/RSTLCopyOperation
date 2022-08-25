#import "KBProgress.h"

inline KBProgress * KBMakeProgress(double elapsedTime, double totalTime, double speed, NSString * _Nullable processingFile) {
    KBProgress *pc = [KBProgress new];
    pc.elapsedTime = elapsedTime;
    pc.totalTime = totalTime;
    pc.speed = speed;
    pc.processingFile = processingFile;
    return pc;
}

@implementation KBProgress

- (double)calculatedRemainingTime {
    NSTimeInterval sec = [[NSDate date] timeIntervalSinceDate:self.start];
    self.speed = self.elapsedTime/sec;
    return (self.totalTime - self.elapsedTime)/self.speed;
}

@end
