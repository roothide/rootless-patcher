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
			printf("Failed to remove already existing .deb file in temporary directory.\n");
			return NO;
		}
	}

	error = nil;
	if (![fileManager fileExistsAtPath:temporaryDirectory]) {
		[fileManager createDirectoryAtPath:temporaryDirectory withIntermediateDirectories:YES attributes:nil error:&error];
		if (error) {
			printf("Failed to create temporary directory.\n");
			return NO;
		}
	}

	error = nil;
	[fileManager copyItemAtPath:file toPath:temporaryDebPath error:&error];
	if (error) {
		printf("Failed to copy .deb to temporary directory.\n");
		return NO;
	}

	NSString *const scriptPath = ROOT_PATH_NS(@"/Library/Application Support/rootless-patcher/repack-rootless.sh");

	const BOOL scriptSucceeded = [SpawnHandler spawnWithArguments:@[
		@"sh",
		scriptPath,
		temporaryDebPath
	]];

	if (!scriptSucceeded) {
		printf("Failed to execute script.\n");
		return NO;
	}

	return YES;
}

@end