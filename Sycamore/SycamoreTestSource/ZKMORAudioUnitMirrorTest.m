//
//  ZKMORAudioUnitMirrorTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 18.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnitMirrorTest.h"
#import <Sycamore/Sycamore.h>


@implementation ZKMORAudioUnitMirrorTest

- (void)testMirror
{
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORAudioUnit* au = [[[ZKMORAudioUnitSystem sharedAudioUnitSystem] effectAudioUnits] objectAtIndex: 0];
	ZKMORAudioUnitMirror* mirror = [[ZKMORAudioUnitMirror alloc] initWithConduit: au];
	[mirror logDebug];
//	ZKMORLogPrinterFlush();
	ZKMORLogPrinterClear();
	ZKMORLoggerSetIsLogging(NO);
	[mirror release];
}

@end
