// Copyright (c) 2024 Nightwind

#include <roothide.h>
#import <Foundation/Foundation.h>
#import "Headers/RPMachOMerger.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPMachOMerger

+ (int)mergeMachOsAtPaths:(NSArray<NSString *> *)paths outputPath:(NSString *)outputPath {
	NSMutableArray *const args = [NSMutableArray array];
	[args addObject:@"lipo"];
	for(NSString *path in paths) {
		[args addObject:rootfs(path)];
	}
	[args addObject:@"-output"];
	[args addObject:rootfs(outputPath)];
	[args addObject:@"-create"];

	return [RPSpawnHandler spawnWithArguments:args];
}

@end