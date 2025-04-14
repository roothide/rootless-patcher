// Copyright (c) 2024 Nightwind

#include <roothide.h>
#import <Foundation/Foundation.h>
#import "Headers/RPRepackHandler.h"
#import "Headers/RPSpawnHandler.h"

@implementation RPRepackHandler

+ (BOOL)repackFile:(NSString *)file toDirectory:(NSString *)directory {
	NSFileManager *const fileManager = [NSFileManager defaultManager];

	NSString *const oldWorkingDirectory = [[directory stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"old_%@", [directory lastPathComponent]]];

	const int unpackStatus = [RPSpawnHandler spawnWithArguments:@[
		@"dpkg-deb",
		@"-R",
		rootfs(file),
		rootfs(oldWorkingDirectory)
	]];

	if (unpackStatus != 0) {
		fprintf(stderr, "[-] Failed to unpack .deb using dpkg-deb\n");
		return NO;
	}

	NSError *error = nil;

	if ([fileManager fileExistsAtPath:[oldWorkingDirectory stringByAppendingPathComponent:@"/var/jb"]]) {
		fprintf(stdout, "[-] File is already rootless, skipping and exiting cleanly...\n");

		const BOOL removeFileSuccess = [fileManager removeItemAtPath:oldWorkingDirectory error:&error];
		if (!removeFileSuccess) {
			fprintf(stderr, "[-] Failed to remove file at path: %s. Error: %s\n", file.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return NO;
		}
	}

	NSString *const newJBRoot = [directory stringByAppendingPathComponent:@"/var/jb"];

	error = nil;
	const BOOL jbrootCreateSuccess = [fileManager createDirectoryAtPath:newJBRoot withIntermediateDirectories:YES attributes:@{
		NSFilePosixPermissions: @(0777)
	} error:&error];
	if (!jbrootCreateSuccess) {
		fprintf(stderr, "[-] Failed to create /var/jb directory at path: %s. Error: %s\n", directory.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return NO;
	}

	error = nil;
	NSArray *const contents = [fileManager contentsOfDirectoryAtPath:oldWorkingDirectory error:&error];

	if (!contents) {
		fprintf(stderr, "[-] Failed to get contents of directory: %s. Error: %s\n", oldWorkingDirectory.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return NO;
	}

	for (NSString *file in contents) {
		error = nil;
		NSString *const oldFilePath = [oldWorkingDirectory stringByAppendingPathComponent:file];
		NSString *const newFilePath = [newJBRoot stringByAppendingPathComponent:[file lastPathComponent]];
		const BOOL fileMoveSuceess = [fileManager moveItemAtPath:oldFilePath toPath:newFilePath error:&error];
		if (!fileMoveSuceess) {
			fprintf(stderr, "[-] Failed to move file %s to %s. Error: %s\n", oldFilePath.fileSystemRepresentation, newFilePath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return NO;
		}
	}

	error = nil;
	NSString *const debianPath = [newJBRoot stringByAppendingPathComponent:@"DEBIAN"];
	const BOOL debianMoveSuccess = [fileManager moveItemAtPath:debianPath toPath:[directory stringByAppendingPathComponent:@"DEBIAN"] error:&error];
	if (!debianMoveSuccess) {
		fprintf(stderr, "[-] Failed to move DEBIAN: %s. Error: %s\n", debianPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return NO;
	}

	const BOOL oldWorkingDirectoryRemoveSuccess = [fileManager removeItemAtPath:oldWorkingDirectory error:&error];
	if (!oldWorkingDirectoryRemoveSuccess) {
		fprintf(stderr, "[-] Failed to remove file at path: %s. Error: %s\n", file.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return NO;
	}

	return YES;
}

@end