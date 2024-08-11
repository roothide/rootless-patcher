#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@interface DirectoryScanner : NSObject
+ (nullable instancetype)directoryScannerWithDirectory:(nonnull NSString *)directory;
- (nullable NSArray<NSString *> *)machOFiles;
- (nullable NSArray<NSString *> *)plistFiles;
- (nullable NSArray<NSString *> *)controlScriptFiles;
- (nullable NSString *)controlFile;

+ (nullable instancetype)new __attribute__((unavailable("Use +directoryScannerWithDirectory: instead")));
- (nullable instancetype)init __attribute__((unavailable("Use +directoryScannerWithDirectory: instead")));
@end