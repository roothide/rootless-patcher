#import <Foundation/Foundation.h>
#import <rootless.h>
#import "Headers/RPScriptHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPScriptHandler

+ (BOOL)handleScriptForFile:(NSString *)file {
	NSString *const scriptPath = ROOT_PATH_NS(@"/Library/Application Support/rootless-patcher/repack-rootless.sh");

	const int scriptStatus = [RPSpawnHandler spawnWithArguments:@[
		@"sh",
		scriptPath,
		file
	]];

	if (scriptStatus != 0) {
		fprintf(stderr, "[-] Failed to execute script: %s\n", scriptPath.fileSystemRepresentation);
		return NO;
	}

	return YES;
}

@end