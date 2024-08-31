#import <Foundation/Foundation.h>
#import <rootless.h>
#import "Headers/RPScriptHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPScriptHandler

+ (BOOL)handleScriptForFile:(NSString *)file {
	NSFileManager *const fileManager = [NSFileManager defaultManager];

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

	NSString *const libCachePath = [file stringByAppendingPathComponent:@"._lib_cache"];

	NSError *error = nil;
	const BOOL success = [fileManager removeItemAtPath:libCachePath error:&error];
	if (!success) {
		fprintf(stderr, "[-] Failed to ._lib_cache: %s. Error: %s\n", libCachePath.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return NO;
	}

	return YES;
}

@end