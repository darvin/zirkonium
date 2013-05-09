//
//  ZKMORException.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 23.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORException.h"

NSString* const ConduitError = @"ConduitError";
NSString* const GraphError = @"GraphError";
NSString* const AudioUnitError = @"AudioUnitError";
NSString* const ClockError = @"ClockError";


NSException* ZKMORExceptionWithSourceInfo(	NSString*		name,
											id				thrower,
											const char*		fileName,
											int				lineNumber,
											NSString*		format,
											...)
{	
	NSDictionary* infoDict = 
		[NSDictionary 
			dictionaryWithObjectsAndKeys: 
				[NSString stringWithCString: fileName], @"ZKMORFileName",
				[NSNumber numberWithInt: lineNumber], @"ZKMORLineNumber",
				nil];
	va_list argList;
	va_start(argList, format);
	NSString* reasonDesc = [[NSString alloc] initWithFormat:format arguments:argList];
	va_end(argList);
	NSString* reason = [NSString stringWithFormat:  @"%@ on line %i of %s :\n%@", name, fileName, lineNumber, reasonDesc];
	[reasonDesc release];
	return 
		[NSException 
			exceptionWithName: name
			reason: reason
			userInfo: infoDict];
}											


@implementation NSException (ZKMORException)

- (NSString *)filename 
{ 
	NSDictionary* myUserInfo = [self userInfo];
	if (!myUserInfo) return nil;
	return [myUserInfo objectForKey: @"ZKMORFileName"];
}

- (NSNumber *)lineNumber
{ 
	NSDictionary* myUserInfo = [self userInfo];
	if (!myUserInfo) return nil;
	return [myUserInfo objectForKey: @"ZKMORLineNumber"];
}

@end

