// Copyright (c) 2024 Nightwind

#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <Foundation/Foundation.h>
#import "Headers/RPMachOThinner.h"

@implementation RPMachOThinner

+ (NSDictionary *)thinnedMachOsFromPaths:(NSArray<NSString *> *)paths {
	NSMutableDictionary *const thinnedMachOs = [NSMutableDictionary dictionary];

	for (NSString *path in paths) {
		NSArray *const thinnedMachO = [RPMachOThinner _thinnedMachOsFromPath:path];
		[thinnedMachOs setObject:thinnedMachO forKey:path];
	}

	return [thinnedMachOs copy];
}

+ (NSArray<NSString *> *)_thinnedMachOsFromPath:(NSString *)path {
	NSMutableArray *const thinnedMachOs = [NSMutableArray array];

	NSData *const data = [NSData dataWithContentsOfFile:path];

	const struct mach_header_64 *header = (const struct mach_header_64 *)[data bytes];

	if (header->magic == FAT_MAGIC || header->magic == FAT_CIGAM) {
		NSArray<NSString *> *const thinnedMachOsFromFAT = [RPMachOThinner _thinnedMachOsFromFAT:path];
		for (NSString *thinnedMachO in thinnedMachOsFromFAT) {
			[thinnedMachOs addObject:thinnedMachO];
		}
	} else if (header->magic == MH_MAGIC_64 || header->magic == MH_CIGAM_64) {
		NSString *const thinnedPath = [RPMachOThinner _thinnedPathForPath:path cpusubtype:header->cpusubtype];

		NSError *error = nil;
		const BOOL success = [data writeToFile:thinnedPath options:NSDataWritingAtomic error:&error];

		if (success) {
			[thinnedMachOs addObject:thinnedPath];
		} else {
			fprintf(stderr, "[-] Failed to write to %s. Error: %s\n", thinnedPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
		}
	}

	return [thinnedMachOs copy];
}

+ (NSArray<NSString *> *)_thinnedMachOsFromFAT:(NSString *)path {
	NSMutableArray *const thinnedMachOs = [NSMutableArray array];

	NSData *const data = [NSData dataWithContentsOfFile:path];

	const struct fat_header *header = (const struct fat_header *)[data bytes];
	struct fat_arch *arch = (struct fat_arch *)([data bytes] + sizeof(struct fat_header));

	for (uint32_t i = 0; i < OSSwapBigToHostInt32(header->nfat_arch); i++) {
		const struct mach_header_64 *header = (const struct mach_header_64 *)([data bytes] + OSSwapBigToHostInt32(arch->offset));

		if (header->cputype == CPU_TYPE_ARM64) {
			const NSRange sliceRange = NSMakeRange(OSSwapBigToHostInt32(arch->offset), OSSwapBigToHostInt32(arch->size));
			NSData *const subdata = [data subdataWithRange:sliceRange];

			NSString *const thinnedPath = [RPMachOThinner _thinnedPathForPath:path cpusubtype:header->cpusubtype];

			NSError *error = nil;
			const BOOL success = [subdata writeToFile:thinnedPath options:NSDataWritingAtomic error:&error];

			if (success) {
				[thinnedMachOs addObject:thinnedPath];
			} else {
				fprintf(stderr, "[-] Failed to write to %s. Error: %s\n", thinnedPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			}
		}

		arch++;
	}

	return thinnedMachOs;
}

+ (NSString *)_thinnedPathForPath:(NSString *)path cpusubtype:(cpu_subtype_t)cpusubtype {
	NSString *const name = [path lastPathComponent];
	return [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%x_%@", cpusubtype, name]];
}

@end