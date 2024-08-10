#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface CodesignHandler : NSObject
+ (BOOL)removeCodesignFromFile:(nonnull NSString *)file;
+ (BOOL)addCodesignToFile:(nonnull NSString *)file;
@end