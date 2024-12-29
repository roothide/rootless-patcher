// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import "Headers/RPCodesignHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPCodesignHandler

+ (int)removeCodesignFromFile:(NSString *)file {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-r",
		file
	]];
}

+ (int)addCodesignToFile:(NSString *)file {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		@"-S",
		file
	]];
}

+ (int)addCodesignToFile:(NSString *)file entitlementsPath:(NSString *)entitlementsPath {
	return [RPSpawnHandler spawnWithArguments:@[
		@"ldid",
		[@"-S" stringByAppendingString:entitlementsPath],
		file
	]];
}

@end