#import <Foundation/Foundation.h>
#import <rootless.h>
#import "Headers/RPScriptHandler.h"
#import "Headers/RPDirectoryScanner.h"
#import "Headers/RPMachOThinner.h"
#import "Headers/RPStringScanner.h"
#import "Headers/RPMachOModifier.h"
#import "Headers/RPOldABIChecker.h"
#import "Headers/RPPlistHandler.h"
#import "Headers/RPControlScriptHandler.h"
#import "Headers/RPControlParser.h"
#import "Headers/RPCodesignHandler.h"
#import "Headers/RPMachOMerger.h"
#import "Headers/RPSpawnHandler.h"

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if (argc != 2) {
			fprintf(stdout, "\n");
			fprintf(stdout, "Usage:\n");
			fprintf(stdout, "rootless-patcher <path/to/binary>\n");
			fprintf(stdout, "\n");

			return EXIT_FAILURE;
		}

		fprintf(stdout, "\n[+] Starting rootless-patcher...\n\n");

		NSString *const temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rootless-patcher"];
		NSFileManager *const fileManager = [NSFileManager defaultManager];

		NSString *const debPath = [NSString stringWithUTF8String:argv[1]];
		BOOL isDirectory;
		if (!debPath || ![fileManager fileExistsAtPath:debPath isDirectory:&isDirectory] || isDirectory) {
			fprintf(stderr, "[-] Cannot find file at path: %s\n", debPath.fileSystemRepresentation);
			return EXIT_FAILURE;
		}

		const BOOL handleScript = [RPScriptHandler handleScriptForFile:debPath];
		if (!handleScript) {
			fprintf(stderr, "[-] Failed to handle script for file: %s\n", debPath.fileSystemRepresentation);
			return EXIT_FAILURE;
		}

		NSString *const patchWorkingDirectoryPath = [NSString stringWithFormat:@"patch_%@", [[debPath lastPathComponent] stringByDeletingPathExtension]];
		NSString *const patchWorkingDirectory = [temporaryDirectory stringByAppendingPathComponent:patchWorkingDirectoryPath];
		if (![fileManager fileExistsAtPath:patchWorkingDirectory]) {
			fprintf(stderr, "[-] Patch working directory does not exist at path: %s\n", patchWorkingDirectoryPath.fileSystemRepresentation);
			return EXIT_FAILURE;
		}

		RPDirectoryScanner *const directoryScanner = [RPDirectoryScanner scannerWithDirectory:patchWorkingDirectory];
		NSArray<NSString *> *const machOFiles = [directoryScanner machOFiles];
		NSArray<NSString *> *const plistFiles = [directoryScanner plistFiles];
		NSArray<NSString *> *const controlScriptFiles = [directoryScanner controlScriptFiles];
		NSString *const controlFile = [directoryScanner controlFile];

		NSDictionary *const allThinnedMachOs = [RPMachOThinner thinnedMachOsFromPaths:machOFiles];

		NSString *const conversionRulesetPath = ROOT_PATH_NS(@"/Library/Application Support/rootless-patcher/ConversionRuleset.json");
		NSData *const conversionRulesetData = [NSData dataWithContentsOfFile:conversionRulesetPath];

		NSError *error = nil;
		NSDictionary *const conversionRuleset = [NSJSONSerialization JSONObjectWithData:conversionRulesetData options:kNilOptions error:&error];
		if (!conversionRuleset) {
			fprintf(stderr, "[-] Could not find ConversionRuleset.json at path: %s. Error: %s\n", conversionRulesetPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		fprintf(stdout, "[+] Starting string conversion portion...\n");

		BOOL containsOldABI = NO;

		error = nil;
		for (NSString *fatMachO in allThinnedMachOs) {
			NSArray<NSString *> *const thinnedMachOs = [allThinnedMachOs objectForKey:fatMachO];

			for (NSString *file in thinnedMachOs) {
				RPStringScanner *const stringScanner = [RPStringScanner scannerWithFile:file conversionRuleset:conversionRuleset];
				NSDictionary<NSString *, NSString *> *const stringMap = [stringScanner stringMap];

				RPMachOModifier *const modifier = [RPMachOModifier modifierWithFile:file];
				[modifier addSegment:@"__PATCH_ROOTLESS" withSection:@"__cstring" withStringMap:stringMap];
				[modifier rebaseStringsWithStringMap:stringMap];

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

			const int machOMergeStatus = [RPMachOMerger mergeMachOsAtPaths:thinnedMachOs outputPath:fatMachO];
			if (machOMergeStatus != 0) {
				fprintf(stderr, "[-] Failed to merge Mach-O's: %s\n", thinnedMachOs.description.UTF8String);
				break;
			}

			error = nil;
			const BOOL attributeSetSuccess = [fileManager setAttributes:fileAttributes ofItemAtPath:fatMachO error:&error];
			if (!attributeSetSuccess) {
				fprintf(stderr, "[-] Failed to set attributes for file at path: %s. Error: %s\n", fatMachO.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			const int addCodesignStatus = [RPCodesignHandler addCodesignToFile:fatMachO];
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

		RPControlParser *const controlParser = [RPControlParser parserWithControlFile:controlFile];
		if (containsOldABI) {
			NSMutableArray *const dependencies = [controlParser controlValueForKey:@"Depends"];
			[dependencies addObject:@"cy+cpu.arm64v8 | oldabi-xina | oldabi"];
		}

		[controlParser setControlValue:@"iphoneos-arm64" forKey:@"Architecture"];

		NSString *const packageID = [controlParser controlValueForKey:@"Package"];
		NSString *const packageVersion = [controlParser controlValueForKey:@"Version"];

		error = nil;
		const BOOL writeSuccess = [[controlParser controlFileAsString] writeToFile:controlFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
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

		fprintf(stdout, "[+] Starting control script file portion...\n");

		error = nil;
		for (NSString *controlScriptFile in controlScriptFiles) {
			NSDictionary<NSFileAttributeKey, id> *const fileAttributes = [fileManager attributesOfItemAtPath:controlScriptFile error:&error];
			if (!fileAttributes) {
				fprintf(stderr, "[-] Failed to get file attributes for control script file: %s. Error: %s\n", controlScriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			RPControlScriptHandler *const handler = [RPControlScriptHandler handlerWithControlScriptFile:controlScriptFile];
			[handler convertStringsUsingConversionRuleset:conversionRuleset];

			error = nil;
			NSString *const convertedFileContents = [handler fileContents];
			const BOOL writeSuccess = [convertedFileContents writeToFile:controlScriptFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
			if (!writeSuccess) {
				fprintf(stderr, "[-] Failed to write to file: %s. Error: %s\n", controlScriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}

			error = nil;
			const BOOL attributeSetSuccess = [fileManager setAttributes:fileAttributes ofItemAtPath:controlScriptFile error:&error];
			if (!attributeSetSuccess) {
				fprintf(stderr, "[-] Failed to set file attributes for control script file: %s. Error: %s\n", controlScriptFile.fileSystemRepresentation, error.localizedDescription.UTF8String);
				break;
			}
		}

		fprintf(stdout, "[+] Finishing control file portion...\n");

		NSString *const newPath = [[debPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@_iphoneos-arm64.deb", packageID, packageVersion]];

		const int dpkgDebStatus = [RPSpawnHandler spawnWithArguments:@[
			@"dpkg-deb",
			@"-b",
			patchWorkingDirectory,
			newPath
		]];

		if (dpkgDebStatus != 0) {
			fprintf(stderr, "[-] Failed to build .deb using dpkg-deb");
		}

		error = nil;
		const BOOL patchWorkingDirectoryRemoveSuccess = [fileManager removeItemAtPath:patchWorkingDirectory error:&error];
		if (!patchWorkingDirectoryRemoveSuccess) {
			fprintf(stderr, "[-] Error removing patch working directory: %s. Error: %s\n", patchWorkingDirectory.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		NSString *const temporaryDebPath = [temporaryDirectory stringByAppendingPathComponent:[debPath lastPathComponent]];
		error = nil;
		const BOOL temporaryDirectoryRemoveSuccess = [fileManager removeItemAtPath:temporaryDebPath error:&error];
		if (!temporaryDirectoryRemoveSuccess) {
			fprintf(stderr, "[-] Error removing temporary .deb path: %s. Error: %s\n", temporaryDebPath.fileSystemRepresentation, error.localizedDescription.UTF8String);
			return EXIT_FAILURE;
		}

		fprintf(stdout, "\n[+] Done! New .deb path: %s\n\n", newPath.fileSystemRepresentation);

		return EXIT_SUCCESS;
	}
}
