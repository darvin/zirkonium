//
//  ZKMORTestToolDriver.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  This is for debugging -- it is easier to debug the tests inside
//  Xcode instead of going through the otest app.
//



#import <SenTestingKit/SenTestingKit.h>
#import "ZKMORAudioFileRecorderTest.h"

int main (int argc, const char * argv[])
{

	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	[SenTestObserver class];

	SenTestSuite* suite;
	suite = 
		[SenTestSuite 
			testSuiteForTestCaseClass: [ZKMORAudioFileRecorderTest class]];
	if (!suite) NSLog(@"Suite is nil!");
	[suite run];
	
	[pool release];
	return 0;
}