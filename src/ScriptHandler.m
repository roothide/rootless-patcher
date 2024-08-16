#import <Foundation/Foundation.h>
#import <rootless.h>
#import "Headers/ScriptHandler.h"
#import "Headers/SpawnHandler.h"

@implementation ScriptHandler

+ (BOOL)handleScriptForFile:(NSString *)file {
	NSError *error;

	NSFileManager *const fileManager = [NSFileManager defaultManager];
	NSString *const temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rootless-patcher"];

	NSString *const deb = [file lastPathComponent];
	NSString *const temporaryDebPath = [temporaryDirectory stringByAppendingPathComponent:deb];

	if ([fileManager fileExistsAtPath:temporaryDebPath]) {
		[fileManager removeItemAtPath:temporaryDebPath error:&error];
		if (error) {
			fprintf(stderr, "[-] Failed to remove already existing .deb file in temporary directory: %s. Error: %s\n", temporaryDebPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return NO;
		}
	}

	error = nil;
	if (![fileManager fileExistsAtPath:temporaryDirectory]) {
		[fileManager createDirectoryAtPath:temporaryDirectory withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			fprintf(stderr, "[-] Failed to create temporary directory: %s. Error: %s\n", temporaryDirectory.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return NO;
		}
	}

	error = nil;
	[fileManager copyItemAtPath:file toPath:temporaryDebPath error:&error];
	if (error) {
		fprintf(stderr, "[-] Failed to copy .deb %s to temporary directory %s. Error: %s\n", file.fileSystemRepresentation, temporaryDirectory.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return NO;
	}

	NSString *const scriptPath = ROOT_PATH_NS(@"/Library/Application Support/rootless-patcher/repack-rootless.sh");

	const int scriptStatus = [SpawnHandler spawnWithArguments:@[
		@"sh",
		scriptPath,
		temporaryDebPath
	]];

	if (scriptStatus != 0) {
		fprintf(stderr, "[-] Failed to execute script: %s. Error: %s\n", scriptPath.fileSystemRepresentation, [SpawnHandler errorForCode:scriptStatus].UTF8String);
		return NO;
	}

	return YES;
}

@end