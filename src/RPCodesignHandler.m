// Copyright (c) 2024 Nightwind

#include <roothide.h>
#import <Foundation/Foundation.h>
#import "Headers/RPCodesignHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPCodesignHandler

+ (int)removeCodesignFromFile:(NSString *)file {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-r",
		rootfs(file)
	]];
}

+ (int)addCodesignToFile:(NSString *)file {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-S",
		rootfs(file)
	]];
}

+ (int)addCodesignToFile:(NSString *)file entitlementsPath:(NSString *)entitlementsPath {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		[@"-S" stringByAppendingString:entitlementsPath],
		rootfs(file)
	]];
}

@end