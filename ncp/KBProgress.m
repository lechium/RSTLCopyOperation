#import "KBProgress.h"
#import "RSTLCopyOperation.h" //log shiz

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

- (NSProgress *)progressRepresentation {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:self.totalTime];
    progress.completedUnitCount = self.elapsedTime;
    if (@available(macOS 10.13, *)) {
        progress.estimatedTimeRemaining = @(self.calculatedRemainingTime);
        progress.throughput = @(self.speed);
    } else {
        // Fallback on earlier versions
    }
    return progress;
}

@end
