//
//  ZKMORDeviceOutputTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 31.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORDeviceOutputTest.h"
#include <unistd.h>

@implementation ZKMORDeviceOutputTest

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

- (void)testOutput
{	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
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
	[deviceOutput start];
	// sleep for half a second to let the audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	[deviceOutput setVolume: 1.f];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertTrue([deviceOutput lastError] == noErr, @"Running output encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the graph was silent");
}

- (void)testInput
{	
	// don't run the test if I have no input
	if (![deviceOutput canDeliverInput]) return;
	
	// set up stream formats -- this needs to be done before initialization
	ZKMORDeviceInput* input = [deviceOutput deviceInput];
	AudioStreamBasicDescription streamFormat = [[input outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [input outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[deviceOutput setGraph: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
		// don't want to listen to annoying noise burst
	[deviceOutput setVolume: 0.01f];
	[deviceOutput start];
	// sleep for half a second to let the audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	[deviceOutput setVolume: 1.f];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertTrue([deviceOutput lastError] == noErr, @"Running input encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The input from the device was silent (not necessarily an error)");
	
	// change stream formats
	[graph beginPatching];
		[mixer uninitialize];
		
		// change stream formats
		[input setNumberOfChannels: 4];
		streamFormat = [[input outputBusAtIndex: 0] streamFormat];
		[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
		[graph patchBus: [input outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
		// don't want to listen to annoying noise burst
	[deviceOutput setVolume: 0.01f];
	[deviceOutput start];
	// sleep for half a second to let the audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	[deviceOutput setVolume: 1.f];

	postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertTrue([deviceOutput lastError] == noErr, @"Running input encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The input from the device was silent (not necessarily an error)");
	
	// change stream formats again
	[graph beginPatching];
		[mixer uninitialize];
		
		// change stream formats
		[input setNumberOfChannels: 6];
		streamFormat = [[input outputBusAtIndex: 0] streamFormat];
		[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
		[graph patchBus: [input outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
		// don't want to listen to annoying noise burst
	[deviceOutput setVolume: 0.01f];
	[deviceOutput start];
	// sleep for half a second to let the audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	[deviceOutput setVolume: 1.f];

	postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertTrue([deviceOutput lastError] == noErr, @"Running input encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The input from the device was silent (not necessarily an error)");
}

- (void)testOutputChannelMap
{	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
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
		// create a channel map which doesn't use channel 1 and sends the output to channel 2
	NSMutableArray* channelMap = [deviceOutput channelMap];	
	[channelMap replaceObjectAtIndex: 0 withObject: [NSNumber numberWithInt: -1]];
	[deviceOutput setChannelMap: channelMap];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
	Float64 startTime = [[deviceOutput clock] currentTimeSeconds];
		// don't want to listen to annoying noise burst
	[deviceOutput setVolume: 0.01f];
	[deviceOutput start];
	// sleep for half a second to let the audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	Float64 endTime = [[deviceOutput clock] currentTimeSeconds];
	[deviceOutput setVolume: 1.f];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertTrue([deviceOutput lastError] == noErr, @"Running output encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the graph was silent");
		// elapsed time should be somewhere in the ballpark of the 0.5 sec sleep time
	STAssertTrue(endTime - startTime > 0.4, @"The clock did not advance while the device ran");
	
	// sleep for another half a second and check that the clock has not advanced
	usleep(500 * 1000);
	STAssertEquals([[deviceOutput clock] currentTimeSeconds], endTime, @"Clock advanced after stopping");

		// clear the channel map
	[deviceOutput setChannelMap: nil];	
	channelMap = [deviceOutput channelMap];
	STAssertEquals([[channelMap objectAtIndex: 0] intValue], 0, @"Channel Map at 0 should be 0");
		// Channel map at 1 should be 0 because I told the output device to be mono, so it created duplicate stereo.
	STAssertEquals([[channelMap objectAtIndex: 1] intValue], 0, @"Channel Map at 1 should be 0");	
}


- (void)testInputChannelMap
{	
	// don't run the test if I have no input
	if (![deviceOutput canDeliverInput]) return;
	
	// set up stream formats -- this needs to be done before initialization
	ZKMORDeviceInput* input = [deviceOutput deviceInput];
	AudioStreamBasicDescription streamFormat = [[input outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [input outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[deviceOutput setGraph: graph];
	
		// create a channel map which doesn't use channel 1 and sends the output to channel 2
	NSMutableArray* channelMap = [input channelMap];
	[channelMap replaceObjectAtIndex: 0 withObject: [NSNumber numberWithInt: 1]];
	[deviceOutput setChannelMap: channelMap];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
		// don't want to listen to annoying noise burst
	[deviceOutput setVolume: 0.01f];
	[deviceOutput start];
	// sleep for half a second to let the audio run
	usleep(500 * 1000);
	[deviceOutput stop];
	[deviceOutput setVolume: 1.f];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertTrue([deviceOutput lastError] == noErr, @"Running output encountered an error %u", [deviceOutput lastError]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The input from the device was silent (not necessarily an error)");
		
		// clear the channel map
	[input setChannelMap: nil];	
	channelMap = [input channelMap];
	STAssertEquals([[channelMap objectAtIndex: 0] intValue], 0, @"Channel Map at 0 should be 0");
	STAssertEquals([[channelMap objectAtIndex: 1] intValue], 1, @"Channel Map at 1 should be 1");	
}

@end
