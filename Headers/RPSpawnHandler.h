// Copyright (c) 2024 Nightwind

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface RPSpawnHandler : NSObject
+ (int)spawnWithArguments:(nonnull NSArray<NSString *> *)arguments;
+ (int)spawnWithArguments:(nonnull NSArray<NSString *> *)arguments stdoutPath:(nullable NSString *)stdoutPath stderrPath:(nullable NSString *)stderrPath;
@end