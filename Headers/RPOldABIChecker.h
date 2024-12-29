// Copyright (c) 2024 Nightwind

#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

@interface RPOldABIChecker : NSObject
+ (BOOL)containsOldABI:(nonnull NSData *)machO;
@end