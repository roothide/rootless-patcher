#import <Foundation/Foundation.h>
#import "Headers/MachOMerger.h"
#import "Headers/SpawnHandler.h"

@implementation MachOMerger

+ (BOOL)mergeMachOsAtPaths:(NSArray<NSString *> *)paths outputPath:(NSString *)outputPath {
	NSMutableArray *const args = [NSMutableArray array];
	[args addObject:@"lipo"];
	[args addObjectsFromArray:paths];
	[args addObject:@"-output"];
	[args addObject:outputPath];
	[args addObject:@"-create"];

	return [SpawnHandler spawnWithCommandPath:@"/var/jb/usr/bin/lipo" arguments:args];
}

@end