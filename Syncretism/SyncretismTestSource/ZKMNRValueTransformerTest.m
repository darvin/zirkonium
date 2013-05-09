//
//  ZKMNRValueTransformerTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 04.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRValueTransformerTest.h"


@implementation ZKMNRValueTransformerTest

- (void)testSecondsToHHMMSSMSConversion
{
	unsigned hh, mm, ss, ms;
	SecondsToHHMMSSMS(60., &hh, &mm, &ss, &ms);
	STAssertEquals(hh, 0U, @"60 seconds have 0 hours");
//	typeof(mm) a1value = (mm); NSValue *a1encoded = [NSValue value:  &a1value withObjCType: @encode(typeof(mm))];
	STAssertEquals(mm, 1U, @"60 seconds have 1 min");
	STAssertEquals(ss, 0U, @"60 seconds have 0 seconds");
	STAssertEquals(ms, 0U, @"60 seconds have 0 ms");
	
	SecondsToHHMMSSMS(130.1, &hh, &mm, &ss, &ms);
	STAssertEquals(hh, 0U, @"130.1 seconds have 0 hours");
	STAssertEquals(mm, 2U, @"130.1 seconds have 2 mins");
	STAssertEquals(ss, 10U, @"130.1 seconds have 10 seconds");
	STAssertEquals(ms, 100U, @"130.1 seconds have 100 ms");
	
	SecondsToHHMMSSMS(3670.02, &hh, &mm, &ss, &ms);
	STAssertEquals(hh, 1U, @"3670.02 seconds have 1 hour");
	STAssertEquals(mm, 1U, @"3670.02 seconds have 1 mins");
	STAssertEquals(ss, 10U, @"3670.02 seconds have 10 seconds");
	STAssertEquals(ms, 20U, @"3670.02 seconds have 20 ms");	
}

- (void)testHHMMSSMSToSecondsConversion
{
	Float64 seconds;
	HHMMSSMSToSeconds(0, 0, 2, 0, &seconds);
	STAssertEqualsWithAccuracy(seconds, 2., 0.0001, @"2 seconds");
	
	HHMMSSMSToSeconds(0, 1, 0, 0, &seconds);
	STAssertEqualsWithAccuracy(seconds, 60., 0.0001, @"1 min");
	
	HHMMSSMSToSeconds(0, 2, 10, 100, &seconds);
	STAssertEqualsWithAccuracy(seconds, 130.1, 0.0001, @"2 min 10 sec 100 ms");

	HHMMSSMSToSeconds(1, 1, 10, 20, &seconds);
	STAssertEqualsWithAccuracy(seconds, 3670.02, 0.0001, @"1 hr 1 min 10 sec 20 ms");
}

- (void)testSecondsToMMSSMSConversion
{

	unsigned mm, ss, ms;
	SecondsToMMSSMS(60., &mm, &ss, &ms);
	STAssertEquals(mm, 1U, @"60 seconds have 1 min");
	STAssertEquals(ss, 0U, @"60 seconds have 0 seconds");
	STAssertEquals(ms, 0U, @"60 seconds have 0 ms");


	SecondsToMMSSMS(130.1, &mm, &ss, &ms);
	STAssertEquals(mm, 2U, @"130.1 seconds have 2 mins");
	STAssertEquals(ss, 10U, @"130.1 seconds have 10 seconds");
	STAssertEquals(ms, 100U, @"130.1 seconds have 100 ms");


	SecondsToMMSSMS(3670.02, &mm, &ss, &ms);
	STAssertEquals(mm, 61U, @"3670.02 seconds have 61 mins");
	STAssertEquals(ss, 10U, @"3670.02 seconds have 10 seconds");
	STAssertEquals(ms, 20U, @"3670.02 seconds have 20 ms");	
}

- (void)testMMSSMSToSecondsConversion
{
	Float64 seconds;
	MMSSMSToSeconds(0, 2, 0, &seconds);
	STAssertEqualsWithAccuracy(seconds, 2., 0.0001, @"2 seconds");
	
	MMSSMSToSeconds(1, 0, 0, &seconds);
	STAssertEqualsWithAccuracy(seconds, 60., 0.0001, @"1 min");
	
	MMSSMSToSeconds(2, 10, 100, &seconds);
	STAssertEqualsWithAccuracy(seconds, 130.1, 0.0001, @"2 min 10 sec 100 ms");

	MMSSMSToSeconds(61, 10, 20, &seconds);
	STAssertEqualsWithAccuracy(seconds, 3670.02, 0.0001, @"1 hr 1 min 10 sec 20 ms");
}

@end
