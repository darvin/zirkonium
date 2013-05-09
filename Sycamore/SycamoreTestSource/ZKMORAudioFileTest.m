//
//  ZKMORAudioFileTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 13.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioFileTest.h"


@implementation ZKMORAudioFileTest

- (void)setUp
{
	[super setUp];
	file = [[ZKMORAudioFile alloc] init];
}

- (void)tearDown
{
	[file release];
	[super tearDown];
}

	// this is a test, but I want to call it mys elf, so don't use the word test in the name
- (void)readMP3
{
	[file setFilePath: [self mp3TestFilePath] error: nil];
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[file outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [file outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
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
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio file was silent");
	
	[graph stop];
}

	// this is a test, but I want to call it mys elf, so don't use the word test in the name
- (void)readJunk
{
	NSError* error = nil;
	[file setFilePath: @"non-existant-file.wav" error: &error];
	STAssertNotNil(error, @"Openeing a non-existant file should have produced an error");
}

	// this is a test, but I want to call it mys elf, so don't use the word test in the name
- (void)readAIFF
{
	[file setFilePath: [self aiffTestFilePath] error: nil];
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[file outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [file outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
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
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio file was silent");
	
	[graph stop];
}

- (void)testReading
{
	[self readMP3];
	[self readJunk];
	[mixer uninitialize];
	[self readAIFF];
}

@end
