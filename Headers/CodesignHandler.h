#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface CodesignHandler : NSObject
+ (int)removeCodesignFromFile:(nonnull NSString *)file;
+ (int)addCodesignToFile:(nonnull NSString *)file;
@end