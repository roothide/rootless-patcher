#import <Foundation/Foundation.h>
#import "Headers/ScriptHandler.h"
#import "Headers/SpawnHandler.h"

@implementation ScriptHandler

+ (BOOL)handleScriptForFile:(nonnull NSString *)file {
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

	const BOOL scriptSucceeded = [SpawnHandler spawnWithCommandPath:@"/var/jb/bin/sh" arguments:@[
		@"sh",
		@"/var/jb/Library/Application Support/rootless-patcher/repack-rootless.sh",
		temporaryDebPath
	]];

	if (!scriptSucceeded) {
		printf("Failed to execute script.\n");
		return NO;
	}

	return YES;
}

@end