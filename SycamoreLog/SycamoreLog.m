#import <Foundation/Foundation.h>
#import "SycamoreLogPrinter.h"
#import "ZKMORLogger.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	
	SycamoreLogPrinter* printer = [[SycamoreLogPrinter alloc] init];
	ZKMORLogDebug(CFSTR("Hello World"));
	ZKMORLogError(kZKMORLogSource_Irrelevant, CFSTR("Error!"));

	[printer release];
    [pool release];
    return 0;
}
