#import <spawn.h>
#import <Foundation/Foundation.h>
#import "Headers/SpawnHandler.h"

@implementation SpawnHandler

+ (BOOL)spawnWithCommandPath:(NSString *)commandPath arguments:(NSArray<NSString *> *)arguments {
	pid_t pid;

	const size_t arraySize = [arguments count];

	char **argumentsC = (char **)malloc(arraySize * sizeof(char *) + 1);
	for (size_t i = 0; i < arraySize; i++) {
		argumentsC[i] = (char *)[arguments[i] UTF8String];
	}
	argumentsC[arraySize] = NULL;

	int status = posix_spawn(&pid, [commandPath fileSystemRepresentation], NULL, NULL, (char *const *)argumentsC, NULL);
	free((void *)argumentsC);

	waitpid(pid, NULL, 0);

	return status == 0;
}

@end