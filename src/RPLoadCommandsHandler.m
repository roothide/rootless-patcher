// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import <roothide.h>
#import "Headers/RPLoadCommandsHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPLoadCommandsHandler

+ (BOOL)handleLoadCommandsForFile:(NSString *)file {
	NSString *const scriptPath = jbroot(@"/Library/Application Support/rootless-patcher/repack-rootless.sh");

	const int scriptStatus = [RPSpawnHandler spawnWithArguments:@[
		@"sh",
		rootfs(scriptPath),
		rootfs(file)
	]];

	if (scriptStatus != 0) {
		fprintf(stderr, "[-] Failed to execute script: %s\n", scriptPath.fileSystemRepresentation);
		return NO;
	}

	return YES;
}

@end