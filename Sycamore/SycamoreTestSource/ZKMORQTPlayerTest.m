//
//  ZKMORQTPlayerTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORQTPlayerTest.h"


@implementation ZKMORQTPlayerTest

- (void)setUp
{
	[super setUp];
	qtPlayer = [[ZKMORQTPlayer alloc] init];
}

- (void)tearDown
{
	[qtPlayer release];
	[super tearDown];
}

- (void)testRead
{
	[qtPlayer setFilePath: [self mp3TestFilePath] error: nil];
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[qtPlayer outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [qtPlayer outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
	[graph start];
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio file player was silent");
	
	[graph stop];
}

- (void)testNoPath
{
	// same as above, but don't set a path
//	[qtPlayer setFilePath: [self mp3TestFilePath] error: nil];
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[qtPlayer outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [qtPlayer outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
	[graph start];
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower < -120.f, @"The output of the audio file player without a path should be silent");
	
	[graph stop];
}


@end
