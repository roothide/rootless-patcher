// Copyright (c) 2024 Nightwind

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

@interface RPMachOThinner : NSObject
+ (nonnull NSDictionary *)thinnedMachOsFromPaths:(nonnull NSArray<NSString *> *)paths;
@end