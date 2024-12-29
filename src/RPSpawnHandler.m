// Copyright (c) 2024 Nightwind

#import <spawn.h>
#import <Foundation/Foundation.h>
#import "Headers/RPSpawnHandler.h"

@implementation RPSpawnHandler

+ (int)spawnWithArguments:(NSArray<NSString *> *)arguments {
	return [RPSpawnHandler spawnWithArguments:arguments stdoutPath:nil stderrPath:nil];
}

+ (int)spawnWithArguments:(NSArray<NSString *> *)arguments stdoutPath:(NSString *)stdoutPath stderrPath:(NSString *)stderrPath {
    extern char **environ;
    pid_t pid;

    posix_spawn_file_actions_t actions = NULL;
    if (stdoutPath || stderrPath) {
        posix_spawn_file_actions_init(&actions);
    }

    if (stdoutPath) {
        posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, stdoutPath.fileSystemRepresentation, O_WRONLY | O_CREAT, 0644);
    }

    if (stderrPath) {
        posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, stderrPath.fileSystemRepresentation, O_WRONLY | O_CREAT, 0644);
    }

    const NSUInteger arraySize = [arguments count];

	const char *argumentsC[arraySize + 1];
    for (NSUInteger i = 0; i < arraySize; i++) {
        argumentsC[i] = [arguments[i] UTF8String];
    }
    argumentsC[arraySize] = NULL;

    int status = posix_spawnp(&pid, argumentsC[0], &actions, NULL, (char *const *)argumentsC, environ);

    waitpid(pid, NULL, 0);

    return status;
}

@end