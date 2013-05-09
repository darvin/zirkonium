//
//  ZKMNRTestToolDriver.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 21.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  This is for debugging -- it is easier to debug the tests inside
//  Xcode instead of going through the otest app.
//


#import <SenTestingKit/SenTestingKit.h>
#import "ZKMNRPannerEventTest.h"

int main (int argc, const char * argv[])
{

	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	[SenTestObserver class];

	SenTestSuite* suite = 
		[SenTestSuite 
			testSuiteForTestCaseClass: [ZKMNRPannerEventTest class]];
	[suite run];

	[pool release];
	return 0;
}