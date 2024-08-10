#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@interface PlistHandler : NSObject
+ (nullable instancetype)handlerWithPlistFile:(nonnull NSString *)file;
- (void)convertStringsUsingStringMap:(nonnull NSDictionary<NSString *, NSString *> *)stringMap;
- (nonnull NSDictionary *)plistDictionary;
@end