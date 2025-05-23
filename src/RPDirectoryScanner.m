// Copyright (c) 2024 Nightwind

#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <Foundation/Foundation.h>
#import "Headers/RPDirectoryScanner.h"

@implementation RPDirectoryScanner {
	NSString *_directory;
}

+ (instancetype)scannerWithDirectory:(NSString *)directory {
	RPDirectoryScanner *const scanner = [RPDirectoryScanner new];

	if (scanner) {
		scanner->_directory = directory;
	}

	return scanner;
}

- (NSArray<NSString *> *)machOFiles {
	__weak typeof(self) weakSelf = self;
	__block NSMutableArray<NSString *> *const files = [NSMutableArray array];

	[self _recursivelyScanDirectory:_directory withBlock:^(NSString *filePath) {
		NSData *const data = [NSData dataWithContentsOfFile:filePath];

		const struct mach_header_64 *header = (const struct mach_header_64 *)[data bytes];
		if (header && [weakSelf _magicMatchesMachO:header->magic]) {
			[files addObject:filePath];
		}
	}];

	return [files count] ? files : nil;
}

- (NSArray<NSString *> *)plistFiles {
	__block NSMutableArray<NSString *> *const files = [NSMutableArray array];

	[self _recursivelyScanDirectory:_directory withBlock:^(NSString *filePath) {
		if ([[filePath pathExtension] isEqualToString:@"plist"]) {
			[files addObject:filePath];
		}
	}];

	return [files count] ? files : nil;
}

- (NSArray<NSString *> *)scriptFiles {
	__weak typeof(self) weakSelf = self;

	__block NSMutableArray<NSString *> *const files = [NSMutableArray array];

	[self _recursivelyScanDirectory:_directory withBlock:^(NSString *filePath) {
		NSError *error = nil;
		NSString *const fileContents = [NSString stringWithContentsOfFile:filePath encoding:NSASCIIStringEncoding error:&error];
		if (!fileContents) {
			fprintf(stderr, "[-] Failed to get contents of file: %s. Error: %s\n", filePath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return;
		}
		if ([fileContents hasPrefix:@"#!"]) {
			[files addObject:filePath];
		}
	}];

	NSArray<NSString *> *const controlScriptNames = @[@"preinst", @"postinst", @"prerm", @"postrm", @"postrmv", @"extrainst", @"triggers"];

	[self _recursivelyScanDirectory:[_directory stringByAppendingPathComponent:@"DEBIAN"] withBlock:^(NSString *filePath) {
		if (![files containsObject:filePath] && [controlScriptNames containsObject:[filePath lastPathComponent]]) {
			NSData *const data = [NSData dataWithContentsOfFile:filePath];

			const struct mach_header_64 *const header = (const struct mach_header_64 *)[data bytes];

			if (header && ![weakSelf _magicMatchesMachO:header->magic]) {
				[files addObject:filePath];
			}
		}
	}];

	return files;
}

- (NSString *)controlFile {
	NSFileManager *const fileManager = [NSFileManager defaultManager];
	__block NSString *controlFilePath = @"";

	[self _recursivelyScanDirectory:[_directory stringByAppendingPathComponent:@"DEBIAN"] withBlock:^(NSString *filePath) {
		BOOL isDirectory = NO;

		if ([[filePath lastPathComponent] isEqualToString:@"control"] && [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory] && !isDirectory) {
			controlFilePath = filePath;
		}
	}];

	return controlFilePath;
}

- (void)_recursivelyScanDirectory:(NSString *)directory withBlock:(void (^)(NSString *))block {
	NSFileManager *const fileManager = [NSFileManager defaultManager];

	NSError *error = nil;
	NSArray *const subpaths = [fileManager subpathsOfDirectoryAtPath:directory error:&error];
	if (error) {
		fprintf(stderr, "[-] Failed to get subpaths of directory at path: %s. Error: %s\n", directory.fileSystemRepresentation, error.localizedDescription.UTF8String);
		return;
	}

	for (NSString *subpath in subpaths) {
		NSString *const fullPath = [directory stringByAppendingPathComponent:subpath];

		BOOL isDirectory;
		const BOOL fileExists = [fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];

		if (fileExists && !isDirectory) {
			block(fullPath);
		}
	}
}

- (BOOL)_magicMatchesMachO:(uint32_t)magic {
	return magic == MH_MAGIC_64 || magic == MH_CIGAM_64 || magic == FAT_MAGIC || magic == FAT_CIGAM;
}

@end