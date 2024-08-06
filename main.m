#import <Foundation/Foundation.h>
#import "Headers/ScriptHandler.h"
#import "Headers/DirectoryScanner.h"
#import "Headers/MachOThinner.h"

int main(int argc, char *argv[], char *envp[]) {
	@autoreleasepool {
		if (argc != 2) {
			printf("\n");
			printf("Usage:\n");
			printf("rootless-patcher <path/to/binary>\n");
			printf("\n");

			return 1;
		}

		NSString *const temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"rootless-patcher"];
		NSFileManager *const fileManager = [NSFileManager defaultManager];

		NSString *const debPath = [NSString stringWithUTF8String:argv[1]];
		BOOL isDirectory;
		if (!debPath || ![fileManager fileExistsAtPath:debPath isDirectory:&isDirectory] || isDirectory) return 1;

		const BOOL handleScript = [ScriptHandler handleScriptForFile:debPath];
		if (!handleScript) {
			return 1;
		}

		NSString *const patchWorkingDirectory = [temporaryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"patch_%@", [[debPath lastPathComponent] stringByDeletingPathExtension]]];
		if (![fileManager fileExistsAtPath:patchWorkingDirectory]) return 1;

		DirectoryScanner *const scanner = [DirectoryScanner directoryScannerWithDirectory:patchWorkingDirectory];
		NSArray<NSString *> *const machOFiles = [scanner machOFiles];
		NSArray<NSString *> *const plistFiles = [scanner plistFiles];
		NSArray<NSString *> *const controlScriptFiles = [scanner controlScriptFiles];

		NSDictionary *const thinnedMachOs = [MachOThinner thinnedMachOsFromPaths:machOFiles];

		printf("mach-o's: %s\n", [machOFiles description].UTF8String);
		printf("plists: %s\n", [plistFiles description].UTF8String);
		printf("control scripts: %s\n", [controlScriptFiles description].UTF8String);
		printf("thinnedMachOs: %s\n", [thinnedMachOs description].UTF8String);

		return 0;
	}
}
