//
//  ZKMORAudioUnitParameterSchedulerTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 17.05.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioUnitParameterSchedulerTest.h"
#import "ZKMORAudioUnitParameterScheduler.h"
#include <unistd.h>


@implementation ZKMORAudioUnitParameterSchedulerTest

- (void)setUp
{
	[super setUp];
	deviceOutput = [[ZKMORDeviceOutput alloc] init];
}

- (void)tearDown
{
	[deviceOutput release];
	[super tearDown];
}

- (void)testSchedulerWithOutput
{	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	ZKMORAudioUnitParameterScheduler* scheduler = [[ZKMORAudioUnitParameterScheduler alloc] initWithConduit: mixer];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[deviceOutput setGraph: graph];
	STAssertTrue([graph retainCount] == 2, @"The graph's retain count should be 2 not %u", [graph retainCount]);

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
		// don't want to listen to annoying noise burst
	[deviceOutput setVolume: 0.01f];
		// schedule an event on the mixer -- take output to 0.7 over 0.1 seconds
	[scheduler beginScheduling];
		[scheduler scheduleParameter: kMatrixMixerParam_Volume scope: kAudioUnitScope_Output element: 0 value: 0.7f duration: 0.4];
	[scheduler endScheduling];
	[deviceOutput start];
		// sleep for 1/10 of a second to let the audio run	
	usleep(100 * 1000);
		// schedule an event on the mixer -- take output to 0 over 0.4 seconds
	[scheduler beginScheduling];
		[scheduler scheduleParameter: kMatrixMixerParam_Volume scope: kAudioUnitScope_Output element: 0 value: 0.0f duration: 0.4];
	[scheduler endScheduling];
		// sleep to let audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	[deviceOutput setVolume: 1.f];

	STAssertTrue([deviceOutput lastError] == noErr, @"Running output encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the graph was silent");
		// make sure the mixer has come down to 0
	STAssertTrue(0 == [mixer volumeForOutput: 0], @"Ouput 0 should have volume 0, not %.2f", [mixer volumeForOutput: 0]);
	
	unsigned mixerRetainCount = [mixer retainCount];
	[scheduler release];
	STAssertTrue(mixerRetainCount == ([mixer retainCount] + 1), @"Releasing the scheduler should have decreased the mixer's retainCount");
}

@end
