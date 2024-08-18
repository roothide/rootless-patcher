#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@interface RPControlParser : NSObject
+ (nullable instancetype)parserWithControlFile:(nonnull NSString *)controlFile;
- (nonnull NSString *)controlFileAsString;
- (void)setControlValue:(nonnull id)value forKey:(nonnull NSString *)key;
- (nonnull id)controlValueForKey:(nonnull NSString *)key;

+ (nullable instancetype)new __attribute__((unavailable("Use +parserWithControlFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +parserWithControlFile: instead")));
@end