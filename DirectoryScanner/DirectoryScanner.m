#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <Foundation/Foundation.h>
#import "Headers/DirectoryScanner.h"

@implementation DirectoryScanner {
	NSString *_directory;
}

+ (instancetype)directoryScannerWithDirectory:(NSString *)directory {
	DirectoryScanner *const scanner = [DirectoryScanner new];

	if (scanner) {
		scanner->_directory = directory;
	}

	return scanner;
}

- (NSArray<NSString *> *)machOFiles {
	__weak typeof(self) weakSelf = self;
	__block NSMutableArray<NSString *> *const files = [NSMutableArray array];

	[self _recursivelyScanDirectoryWithBlock:^(NSString *filePath) {
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

	[self _recursivelyScanDirectoryWithBlock:^(NSString *filePath) {
		if ([[filePath pathExtension] isEqualToString:@"plist"]) {
			[files addObject:filePath];
		}
	}];

	return [files count] ? files : nil;
}

- (NSArray<NSString *> *)controlScriptFiles {
	__weak typeof(self) weakSelf = self;
	__block NSMutableArray<NSString *> *const files = [NSMutableArray array];

	NSArray<NSString *> *const controlScriptNames = @[@"preinst", @"postinst", @"prerm", @"postrm", @"postrmv"];

	[self _recursivelyScanDirectoryWithBlock:^(NSString *filePath) {
		if ([controlScriptNames containsObject:[filePath lastPathComponent]]) {
			NSData *const data = [NSData dataWithContentsOfFile:filePath];

			const struct mach_header_64 *header = (const struct mach_header_64 *)[data bytes];

			if (header && ![weakSelf _magicMatchesMachO:header->magic]) {
				[files addObject:filePath];
			}
		}
	}];

	return [files count] ? files : nil;
}

- (void)_recursivelyScanDirectoryWithBlock:(void (^)(NSString *))block {
	NSFileManager *const fileManager = [NSFileManager defaultManager];

	NSError *error;
	NSArray *const subpaths = [fileManager subpathsOfDirectoryAtPath:_directory error:&error];
	if (error) {
		printf("Failed to get subpaths of directory.");
		return;
	}

	for (NSString *subpath in subpaths) {
		NSString *const fullPath = [_directory stringByAppendingPathComponent:subpath];

		BOOL isDirectory;
		[fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory];

		if (!isDirectory) {
			block(fullPath);
		}
	}
}

- (BOOL)_magicMatchesMachO:(unsigned long)magic {
	return magic == MH_MAGIC_64 || magic == MH_CIGAM_64 || magic == FAT_MAGIC || magic == FAT_CIGAM;
}

@end