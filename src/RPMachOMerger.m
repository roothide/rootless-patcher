// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import "Headers/RPMachOMerger.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPMachOMerger

+ (int)mergeMachOsAtPaths:(NSArray<NSString *> *)paths outputPath:(NSString *)outputPath {
	NSMutableArray *const args = [NSMutableArray array];
	[args addObject:@"lipo"];
	[args addObjectsFromArray:paths];
	[args addObject:@"-output"];
	[args addObject:outputPath];
	[args addObject:@"-create"];

	return [RPSpawnHandler spawnWithArguments:args];
}

@end