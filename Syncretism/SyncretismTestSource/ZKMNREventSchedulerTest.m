//
//  ZKMNREventSchedulerTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 10.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNREventSchedulerTest.h"


@implementation ZKMNRSchedulerTestEvent

@end

@implementation ZKMNREventSchedulerTest
- (void)setUp
{
	[super setUp];
	scheduler = [[ZKMNREventScheduler alloc] init];
	[scheduler setClock: [simulator clock]];
	[scheduler addTimeDependent: self];
	
	testEvent = [[ZKMNRSchedulerTestEvent alloc] init];
		// 500 ms
	[testEvent setStartTime: 0.5];
	[testEvent setTarget: self];
	[scheduler scheduleEvent: testEvent];
	
	wasEventInvoked = NO;
	wasEventInvokedEarly = NO;
	wasEventInvokedTwice = NO;
}

- (void)tearDown
{
	[scheduler release];
	[super tearDown];

}

- (void)acceptEvent:(ZKMNREvent *)event time:(Float64)now
{
	wasEventInvokedTwice = wasEventInvoked;
	wasEventInvoked = YES;
	if (now < 0.4) wasEventInvokedEarly = YES;
}

- (void)task:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{

}

- (void)scrub:(ZKMNREventTaskTimeRange *)timeRange scheduler:(ZKMNREventScheduler *)scheduler
{

}

- (void)testScheduler
{
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];

	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setGraph: graph];
		// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToDiagonalLevels];

	// start playing
	[simulator start];
	[scheduler task: 0.23];
	STAssertFalse(wasEventInvoked, @"The event should not have been invoked");
	STAssertFalse(wasEventInvokedEarly, @"The event was invoked early");
	STAssertFalse(wasEventInvokedTwice, @"The event was twice");
	[simulator simulateNumCalls: 20 numFrames: 512];
	
	[scheduler task: 0.23];
	STAssertFalse(wasEventInvoked, @"The event should not have been invoked");
	STAssertFalse(wasEventInvokedEarly, @"The event was invoked early");
	STAssertFalse(wasEventInvokedTwice, @"The event was twice");
		// task again -- shouldn't change anything as time has not advanced
	[scheduler task: 0.23];
	STAssertFalse(wasEventInvoked, @"The event should not have been invoked");
	STAssertFalse(wasEventInvokedEarly, @"The event was invoked early");
	STAssertFalse(wasEventInvokedTwice, @"The event was twice");
	[simulator simulateNumCalls: 20 numFrames: 512];
	
	[scheduler task: 0.23];
	STAssertTrue(wasEventInvoked, @"The event should have been invoked");
	STAssertFalse(wasEventInvokedEarly, @"The event was invoked early");
	STAssertFalse(wasEventInvokedTwice, @"The event was twice");
	[simulator simulateNumCalls: 20 numFrames: 512];
	
	[scheduler task: 0.23];
	STAssertTrue(wasEventInvoked, @"The event should have been invoked");
	STAssertFalse(wasEventInvokedEarly, @"The event was invoked early");
	STAssertFalse(wasEventInvokedTwice, @"The event was twice");
	[simulator simulateNumCalls: 20 numFrames: 512];
	
	[scheduler task: 0.23];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the pink noise was silent");
	STAssertTrue(wasEventInvoked, @"The event should have been invoked");
	STAssertFalse(wasEventInvokedEarly, @"The event was invoked early");
	STAssertFalse(wasEventInvokedTwice, @"The event was twice");
	
	[simulator stop];
}

@end
