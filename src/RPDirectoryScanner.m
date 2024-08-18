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

- (NSArray<NSString *> *)controlScriptFiles {
	__weak typeof(self) weakSelf = self;
	__block NSMutableArray<NSString *> *const files = [NSMutableArray array];

	NSArray<NSString *> *const controlScriptNames = @[@"preinst", @"postinst", @"prerm", @"postrm", @"postrmv", @"extrainst"];

	[self _recursivelyScanDirectory:[_directory stringByAppendingPathComponent:@"DEBIAN"] withBlock:^(NSString *filePath) {
		if ([controlScriptNames containsObject:[filePath lastPathComponent]]) {
			NSData *const data = [NSData dataWithContentsOfFile:filePath];

			const struct mach_header_64 *const header = (const struct mach_header_64 *)[data bytes];

			if (header && ![weakSelf _magicMatchesMachO:header->magic]) {
				[files addObject:filePath];
			}
		}
	}];

	return [files count] ? files : nil;
}

- (NSString *)controlFile {
	return [[_directory stringByAppendingPathComponent:@"DEBIAN"] stringByAppendingPathComponent:@"control"];
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
	return OSSwapBigToHostInt32(magic) == MH_MAGIC_64 || OSSwapBigToHostInt32(magic) == FAT_MAGIC;
}

@end