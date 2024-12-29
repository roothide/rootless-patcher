// Copyright (c) 2024 Nightwind


#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@interface RPControlHandler : NSObject
+ (nullable instancetype)handlerWithControlFile:(nonnull NSString *)controlFile;
- (nonnull NSString *)controlFileAsString;
- (void)setControlValue:(nonnull id)value forKey:(nonnull NSString *)key;
- (nonnull id)controlValueForKey:(nonnull NSString *)key;

+ (nullable instancetype)new __attribute__((unavailable("Use +handlerWithControlFile: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +handlerWithControlFile: instead")));
@end