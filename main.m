// Copyright (c) 2024 Nightwind

#import <Foundation/Foundation.h>
#import <roothide.h>
#import <mach-o/loader.h>
#import "Headers/RPRepackHandler.h"
#import "Headers/RPLoadCommandsHandler.h"
#import "Headers/RPDirectoryScanner.h"
#import "Headers/RPMachOThinner.h"
#import "Headers/RPStringScanner.h"
#import "Headers/RPMachOModifier.h"
#import "Headers/RPOldABIChecker.h"
#import "Headers/RPPlistHandler.h"
#import "Headers/RPConversionHandler.h"
#import "Headers/RPScriptHandler.h"
#import "Headers/RPControlHandler.h"
#import "Headers/RPCodesignHandler.h"
#import "Headers/RPMachOMerger.h"
#import "Headers/RPSpawnHandler.h"

int main(int argc, char *argv[]) {
	@autoreleasepool {
		if (argc != 2) {
			fprintf(stdout, "\n");
			fprintf(stdout, "Usage:\n");
			fprintf(stdout, "rootless-patcher <path/to/binary>\n");
			fprintf(stdout, "\n");

			return EXIT_FAILURE;
		}
		
#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
		NSMutableSet<NSString *> *newPaths = [[NSMutableSet alloc] init];
		NSArray<NSString *> *paths = [@(getenv("PATH")) componentsSeparatedByString:@":"];
		for (NSString *path in paths) {
			[newPaths addObject:path];
			[newPaths addObject:jbroot(path)];
		}
		NSString *newPathEnv = [newPaths.allObjects componentsJoinedByString:@":"];
		setenv("PATH", newPathEnv.UTF8String, 1);
#endif

		fprintf(stdout, "\n[+] Starting rootless-patcher...\n\n");

		NSError *error = nil;

		NSString *const temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rootless-patcher"];
		NSFileManager *const fileManager = [NSFileManager defaultManager];

		BOOL isDirectory;
		if (![fileManager fileExistsAtPath:temporaryDirectory isDirectory:&isDirectory] || !isDirectory) {
			const BOOL tempDirectoryCreateSuccess = [fileManager createDirectoryAtPath:temporaryDirectory withIntermediateDirectories:YES attributes:nil error:&error];
			if (!tempDirectoryCreateSuccess) {
				fprintf(stderr, "[-] Failed to temporary directory at %s. Error: %s\n", temporaryDirectory.fileSystemRepresentation, error.localizedDescription.UTF8String);
				return EXIT_FAILURE;
			}
		}

		isDirectory = NO;
#ifdef THEOS_PACKAGE_SCHEME_ROOTHIDE
		NSString *const debPath = [NSString stringWithUTF8String:jbroot(argv[1])];
#else
		NSString *const debPath = [NSString stringWithUTF8String:argv[1]];
#endif
		if (!debPath || ![fileManager fileExistsAtPath:debPath isDirectory:&isDirectory] || isDirectory) {
			fprintf(stderr, "[-] Cannot find file at path: %s\n", debPath.fileSystemRepresentation);
			return EXIT_FAILURE;
		}

		NSString *const patchWorkingDirectory = [temporaryDirectory stringByAppendingPathComponent:[[debPath lastPathComponent] stringByDeletingPathExtension]];
		const BOOL repackSuccess = [RPRepackHandler repackFile:debPath toDirectory:patchWorkingDirectory];
		if (!repackSuccess) {
			fprintf(stderr, "[-] Failed to repack .deb.\n");
			return EXIT_FAILURE;
		}

		RPDirectoryScanner *const directoryScanner = [RPDirectoryScanner scannerWithDirectory:patchWorkingDirectory];
		NSArray<NSString *> *const machOFiles = [directoryScanner machOFiles];
		NSArray<NSString *> *const plistFiles = [directoryScanner plistFiles];
		NSArray<NSString *> *const scriptFiles = [directoryScanner scriptFiles];
		NSString *const controlFile = [directoryScanner controlFile];

		NSDictionary *const allThinnedMachOs = [RPMachOThinner thinnedMachOsFromPaths:machOFiles];

		NSString *const conversionRulesetPath = jbroot(@"/Library/Application Support/rootless-patcher/ConversionRuleset.json");
		NSData *const conversionRulesetData = [NSData dataWithContentsOfFile:conversionRulesetPath];

		error = nil;
		NSDictionary *const conversionRuleset = [NSJSONSerialization JSONObjectWithData:conversionRulesetData options:kNilOptions error:&error];
		if (!conversionRuleset) {
			fprintf(stderr, "[-] Could not find ConversionRuleset.json at path: %s. Error: %s\n", conversionRulesetPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		fprintf(stdout, "[+] Starting string conversion portion...\n");

		BOOL containsOldABI = NO;

		error = nil;
		for (NSString *fatMachO in allThinnedMachOs) {
			NSString *const entitlementsPath = [[fatMachO stringByDeletingPathExtension] stringByAppendingString:@"_ents.plist"];

			const int entitlementsSuccess = [RPSpawnHandler spawnWithArguments:@[
				@"ldid",
				@"-e",
				rootfs(fatMachO)
			] stdoutPath:entitlementsPath stderrPath:nil];

			if (entitlementsSuccess != 0) {
				fprintf(stderr, "[-] Failed to get entitlements of path: %s\n", fatMachO.fileSystemRepresentation);
			}

			const BOOL hasEntitlements = [[NSString stringWithContentsOfFile:entitlementsPath encoding:NSUTF8StringEncoding error:nil] length] > 0;

			NSArray<NSString *> *const thinnedMachOs = [allThinnedMachOs objectForKey:fatMachO];

			for (NSString *file in thinnedMachOs) {
				[RPCodesignHandler removeCodesignFromFile:file];

				RPStringScanner *const stringScanner = [RPStringScanner scannerWithFile:file conversionRuleset:conversionRuleset];
				NSDictionary<NSString *, NSString *> *const stringMap = [stringScanner stringMap];

				RPMachOModifier *const modifier = [RPMachOModifier modifierWithFile:file];
				if ([stringMap count] > 0) {
					NSDictionary<NSString *, NSNumber *> *const offsetMap = [stringScanner offsetMap];
					[modifier addSegment:@"__PATCH_ROOTLESS" section:@"__cstring" stringMap:stringMap];
					[modifier rebaseStringsWithStringMap:stringMap originalOffsetMap:offsetMap];
				}

				NSData *const data = [modifier data];
				[data writeToFile:file options:NSDataWritingAtomic error:nil];

				if (!containsOldABI && [RPOldABIChecker containsOldABI:data]) {
					containsOldABI = YES;
				}
			}

			error = nil;
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:fatMachO error:&error];
			if (!fileAttributes) {
				fprintf(stderr, "[-] Failed to get attributes for file at path: %s. Error: %s\n", fatMachO.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			NSMutableDictionary<NSNumber *, NSString *> *const uniqueThinnedMachOs = [NSMutableDictionary dictionary];
			for (NSString *thinnedMachO in thinnedMachOs) {
				const struct mach_header_64 *header = (struct mach_header_64 *)[[NSData dataWithContentsOfFile:thinnedMachO] bytes];
				[uniqueThinnedMachOs setObject:thinnedMachO forKey:@(header->cpusubtype & ~CPU_SUBTYPE_MASK)];
			}

			const BOOL machOMergeStatus = [RPMachOMerger mergeMachOsAtPaths:[uniqueThinnedMachOs allValues] outputPath:fatMachO];
			if (machOMergeStatus != 0) {
				fprintf(stderr, "[-] Failed to merge Mach-O's: %s\n", uniqueThinnedMachOs.description.UTF8String);
				break;
			}

			error = nil;
			const BOOL attributeSetSuccess = [fileManager setAttributes:fileAttributes ofItemAtPath:fatMachO error:&error];
			if (!attributeSetSuccess) {
				fprintf(stderr, "[-] Failed to set attributes for file at path: %s. Error: %s\n", fatMachO.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			fprintf(stdout, "[+] Checking if %s has entitlements... %s\n", fatMachO.fileSystemRepresentation, hasEntitlements ? "YES" : "NO");

			const BOOL handleScript = [RPLoadCommandsHandler handleLoadCommandsForFile:fatMachO];
			if (!handleScript) {
				fprintf(stderr, "[-] Failed to handle script for file: %s\n", fatMachO.fileSystemRepresentation);
				break;
			}

			const int addCodesignStatus = hasEntitlements ? [RPCodesignHandler addCodesignToFile:fatMachO entitlementsPath:entitlementsPath] : [RPCodesignHandler addCodesignToFile:fatMachO];
			if (addCodesignStatus != 0) {
				fprintf(stderr, "[-] Failed to add code signature to file at path: %s\n", fatMachO.fileSystemRepresentation);
				break;
			}

			for (NSString *file in thinnedMachOs) {
				error = nil;
				const BOOL removeFileSuccess = [fileManager removeItemAtPath:file error:&error];
				if (!removeFileSuccess) {
					fprintf(stderr, "[-] Failed to remove file at path: %s\n", file.fileSystemRepresentation);
					break;
				}
			}

			const BOOL removeEntitlementsFileSuccess = [fileManager removeItemAtPath:entitlementsPath error:&error];
			if (!removeEntitlementsFileSuccess) {
				fprintf(stderr, "[-] Failed to remove file at path: %s\n", entitlementsPath.fileSystemRepresentation);
				break;
			}
		}

		fprintf(stdout, "[+] Finishing string conversion portion...\n");

		fprintf(stdout, "[+] Contains Old ABI - %s\n", containsOldABI ? "YES" : "NO");

		fprintf(stdout, "[+] Starting control file portion...\n");

		error = nil;
		NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:controlFile error:&error];
		if (!fileAttributes) {
			fprintf(stderr, "[-] Failed to get file attributes for control file: %s. Error: %s\n", controlFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		RPControlHandler *const controlHandler = [RPControlHandler handlerWithControlFile:controlFile];
		if (containsOldABI) {
			NSMutableArray *const dependencies = [controlHandler controlValueForKey:@"Depends"];
			if ([dependencies isKindOfClass:[NSArray class]]) {
				[dependencies addObject:@"cy+cpu.arm64v8 | oldabi-xina | oldabi"];
			} else if ([dependencies isKindOfClass:[NSString class]]) {
				[controlHandler setControlValue:@[dependencies, @"cy+cpu.arm64v8 | oldabi-xina | oldabi"] forKey:@"Depends"];
			}
		}

		NSString *const packageIconPath = [controlHandler controlValueForKey:@"Icon"];
		if (packageIconPath) {
			RPConversionHandler *const conversionHandler = [RPConversionHandler handlerWithConversionRuleset:conversionRuleset];
			if ([conversionHandler shouldConvertString:packageIconPath]) {
				NSString *const convertedPackageIconPath = [conversionHandler convertedStringForString:packageIconPath];
				fprintf(stdout, "[+] Converting icon path in control file...\n\t%s -> %s\n", packageIconPath.UTF8String, convertedPackageIconPath.UTF8String);
				[controlHandler setControlValue:packageIconPath forKey:@"Icon"];
			}
		}

		[controlHandler setControlValue:@"iphoneos-arm64" forKey:@"Architecture"];

		NSString *const packageID = [controlHandler controlValueForKey:@"Package"];
		NSString *const packageVersion = [controlHandler controlValueForKey:@"Version"];

		error = nil;
		const BOOL writeSuccess = [[controlHandler controlFileAsString] writeToFile:controlFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
		if (!writeSuccess) {
			fprintf(stderr, "[-] Failed to write to %s. Error: %s\n", controlFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		error = nil;
		const BOOL attributeSetSuccess = [fileManager setAttributes:fileAttributes ofItemAtPath:controlFile error:&error];
		if (!attributeSetSuccess) {
			fprintf(stderr, "[-] Failed to set file attributes for control file: %s. Error: %s\n", controlFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		fprintf(stdout, "[+] Finishing control file portion...\n");

		fprintf(stdout, "[+] Starting plist file portion...\n");

		error = nil;
		for (NSString *plist in plistFiles) {
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:plist error:&error];
			if (!fileAttributes) {
				fprintf(stderr, "[-] Failed to get file attributes for plist file: %s. Error: %s\n", plist.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			RPPlistHandler *const handler = [RPPlistHandler handlerWithPlistFile:plist];
			[handler convertStringsUsingConversionRuleset:conversionRuleset];

			[[handler plistContainer] writeToFile:plist atomically:YES];

			error = nil;
			const BOOL attributeSetSuccess = [fileManager setAttributes:fileAttributes ofItemAtPath:plist error:&error];
			if (!attributeSetSuccess) {
				fprintf(stderr, "[-] Failed to set file attributes for plist file: %s. Error: %s\n", plist.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}
		}

		fprintf(stdout, "[+] Finishing plist file portion...\n");

		fprintf(stdout, "[+] Starting script file portion...\n");

		error = nil;
		for (NSString *scriptFile in scriptFiles) {
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:scriptFile error:&error];
			if (!fileAttributes) {
				fprintf(stderr, "[-] Failed to get file attributes for script file: %s. Error: %s\n", scriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			RPScriptHandler *const handler = [RPScriptHandler handlerWithScriptFile:scriptFile];
			[handler convertStringsUsingConversionRuleset:conversionRuleset];

			error = nil;
			NSString *const convertedFileContents = [handler fileContents];
			const BOOL writeSuccess = [convertedFileContents writeToFile:scriptFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
			if (!writeSuccess) {
				fprintf(stderr, "[-] Failed to write to file: %s. Error: %s\n", scriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			error = nil;
			const BOOL attributeSetSuccess = [fileManager setAttributes:fileAttributes ofItemAtPath:scriptFile error:&error];
			if (!attributeSetSuccess) {
				fprintf(stderr, "[-] Failed to set file attributes for script file: %s. Error: %s\n", scriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}
		}

		fprintf(stdout, "[+] Finishing script file portion...\n");

		NSArray<NSString *> *const controlPathComponents = [controlFile pathComponents];
		NSString *const debianPath = [patchWorkingDirectory stringByAppendingPathComponent:@"DEBIAN"];
		NSString *const controlContainer = [[controlPathComponents componentsJoinedByString:@"/"] stringByDeletingLastPathComponent];

		if (![[controlContainer lastPathComponent] isEqualToString:@"DEBIAN"]) {
			fprintf(stdout, "\n[!] IMPORTANT: Starting a hacky fix for certain tweaks that contain an improper DEBIAN directory structure. This is done in order for dpkg-deb to properly build the .deb.\nThe control container (which should end with DEBIAN), is actually: %s\n\n", controlContainer.fileSystemRepresentation);
			error = nil;

			for (NSString *scriptFile in scriptFiles) {
				error = nil;
				const BOOL moveSuccess = [fileManager moveItemAtPath:scriptFile toPath:[debianPath stringByAppendingPathComponent:[scriptFile lastPathComponent]] error:&error];
				if (!moveSuccess) {
					fprintf(stderr, "[-] Failed to move script to path: %s. Error: %s\n", debianPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
				}
			}

			NSString *const improperStructurePath = [[controlContainer stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"improper_control_directory_structure"];

			error = nil;
			const BOOL renameSuccess = [fileManager moveItemAtPath:controlContainer toPath:improperStructurePath error:&error];
			if (!renameSuccess) {
				fprintf(stderr, "[-] Failed to rename control container. Error: %s\n", error.localizedDescription.UTF8String);
			}

			error = nil;
			NSString *const newControlFilePath = [improperStructurePath stringByAppendingPathComponent:[controlFile lastPathComponent]];
			const BOOL moveSuccess = [fileManager moveItemAtPath:newControlFilePath toPath:[debianPath stringByAppendingPathComponent:[controlFile lastPathComponent]] error:&error];
			if (!moveSuccess) {
				fprintf(stderr, "[-] Failed to move control file to path: %s. Error: %s\n", debianPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			}

			error = nil;
			const BOOL improperDirectoryRemoveSuccess = [fileManager removeItemAtPath:improperStructurePath error:&error];
			if (!improperDirectoryRemoveSuccess) {
				fprintf(stderr, "[-] Failed to remove improper directory. Error: %s\n", error.localizedDescription.UTF8String);
			}
		}

		NSString *const newPath = [[debPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@_iphoneos-arm64.deb", packageID, packageVersion]];

		const int buildStatus = [RPSpawnHandler spawnWithArguments:@[
			@"dpkg-deb",
			@"-b",
			rootfs(patchWorkingDirectory),
			rootfs(newPath)
		]];

		error = nil;
		const BOOL patchWorkingDirectoryRemoveSuccess = [fileManager removeItemAtPath:patchWorkingDirectory error:&error];
		if (!patchWorkingDirectoryRemoveSuccess) {
			fprintf(stderr, "[-] Error removing patch working directory: %s. Error: %s\n", patchWorkingDirectory.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		if (buildStatus != 0) {
			fprintf(stderr, "[-] Failed to build .deb using dpkg-deb\n");
			return EXIT_FAILURE;
		}

		fprintf(stdout, "\n[+] Done! New .deb path: %s\n\n", newPath.fileSystemRepresentation);

		return EXIT_SUCCESS;
	}
}
