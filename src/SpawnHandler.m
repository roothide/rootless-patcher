#import <spawn.h>
#import <Foundation/Foundation.h>
#import "Headers/SpawnHandler.h"

@implementation SpawnHandler

+ (int)spawnWithArguments:(NSArray<NSString *> *)arguments {
	extern char **environ;
	pid_t pid;

	const NSUInteger arraySize = [arguments count];

	char **argumentsC = (char **)malloc(arraySize * sizeof(char *) + 1);
	for (NSUInteger i = 0; i < arraySize; i++) {
		argumentsC[i] = (char *)[arguments[i] UTF8String];
	}
	argumentsC[arraySize] = NULL;

	int status = posix_spawnp(&pid, argumentsC[0], NULL, NULL, (char *const *)argumentsC, environ);
	free((void *)argumentsC);

	waitpid(pid, NULL, 0);

	return status;
}

+ (NSString *)errorForCode:(int)returnCode {
	return [NSString stringWithUTF8String:strerror(returnCode)];
}

@end