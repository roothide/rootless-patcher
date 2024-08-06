#import <Foundation/Foundation.h>
#import "Headers/ScriptHandler.h"

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

		NSString *const patchWorkingDirectory = [temporaryDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"patch_%@", [debPath stringByDeletingPathExtension]]];
		if (![fileManager fileExistsAtPath:patchWorkingDirectory]) return 1;

		return 0;
	}
}
