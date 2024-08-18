#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPCodesignHandler : NSObject
+ (int)removeCodesignFromFile:(nonnull NSString *)file;
+ (int)addCodesignToFile:(nonnull NSString *)file;
@end