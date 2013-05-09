//
//  ZKMORNoiseTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORNoiseTest.h"
#import "ZKMORLogger.h"


@implementation ZKMORNoiseTest

- (void)setUp
{
	whiteNoise = [[ZKMORWhiteNoise alloc] init];
	pinkNoise = [[ZKMORPinkNoise alloc] init];

	graph = [[ZKMORGraph alloc] init];
	mixer = [[ZKMORMixerMatrix alloc] init];
	simulator = [[ZKMORRenderSimulator alloc] init];
	
	[mixer setMeteringOn: YES];

}

- (void)tearDown
{
	[whiteNoise release];
	[pinkNoise release];
	
	[graph release];
	[mixer release];
	[simulator release];
}

- (void)testWhiteNoiseBasic
{
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	// try to log it
	[whiteNoise logDebug];
	ZKMORLogPrinterClear();
	ZKMORLoggerSetIsLogging(NO);
	
	// verify the default stream format
	AudioStreamBasicDescription streamFormat = [[whiteNoise outputBusAtIndex: 0] streamFormat];
	STAssertEquals(streamFormat.mSampleRate, ZKMORDefaultSampleRate(), @"Sample rate should be the default");
	STAssertEquals(streamFormat.mChannelsPerFrame, (UInt32) ZKMORDefaultNumberChannels(), @"Number of channels should be the default");
	
	STAssertNoThrow([whiteNoise initialize], @"Initialize should not throw an exception");
	STAssertNoThrow([whiteNoise uninitialize], @"Uninitialize should not throw an exception");
}

- (void)testWhiteNoise
{
	AudioStreamBasicDescription streamFormat = [[whiteNoise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [whiteNoise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
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
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio filePlayer was silent");
	
	[graph stop];
}

- (void)testPinkNoise
{
	AudioStreamBasicDescription streamFormat = [[pinkNoise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [pinkNoise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
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
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio filePlayer was silent");
	
	[graph stop];
}

@end
