
#define __SHORT_FILE__ basename(__FILE__)
#define ALog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__])
#define DLog(format, ...) ALog(@"%@", [NSString stringWithFormat:format, ## __VA_ARGS__])
#define LineLog(format, ...) ALog(@"[%s:%i] %@", __SHORT_FILE__, __LINE__, [NSString stringWithFormat:format, ## __VA_ARGS__])
#define RSTLog(L, format, ...) [RSTLCopyOperation logLevel:L string:[NSString stringWithFormat:format, ## __VA_ARGS__]]
#define VerboseLog(format, ...)RSTLog(1,format, ## __VA_ARGS__)
#define InfoLog(format, ...)RSTLog(0,format, ## __VA_ARGS__)
#define LOG_SELF        ALog(@"[Copy] %@ %@", self, NSStringFromSelector(_cmd))
#define FANCY_BYTES(B) [NSByteCountFormatter stringFromByteCount:B countStyle:NSByteCountFormatterCountStyleFile]
#define BYTE_PROGRESS(E,T) [NSString stringWithFormat:@"[%@/%@]",FANCY_BYTES(E), FANCY_BYTES(T)]
