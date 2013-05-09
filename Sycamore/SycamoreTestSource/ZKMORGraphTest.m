//
//  ZKMORGraphTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 29.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORGraphTest.h"

static OSStatus GraphTestRenderNotification(	id								SELF, 
												AudioUnitRenderActionFlags		* ioActionFlags,
												const AudioTimeStamp			* inTimeStamp,
												UInt32							inOutputBusNumber,
												UInt32							inNumberFrames,
												AudioBufferList					* ioData)
{
	ZKMORGraphTest* graphTest = (ZKMORGraphTest*) SELF;
		// only check this on the first time through
	if (graphTest->callNumber > 0) {
		graphTest->wereNotificationsCalledAfterRemoval = YES;
		return noErr;
	}

	if (*ioActionFlags & kAudioUnitRenderAction_PreRender) {
		if (graphTest->wasPostRenderCalled)
			graphTest->wereNotificationsCalledInOrder = NO;
		else
			graphTest->wasPreRenderCalled = YES;
	}
	
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
		if (!graphTest->wasPreRenderCalled)
			graphTest->wereNotificationsCalledInOrder = NO;
		else {
			graphTest->wasPostRenderCalled = YES;
			graphTest->wereNotificationsCalledInOrder = YES;
		}
	}
	
	return noErr;
}


@implementation ZKMORGraphTest

- (void)setUp
{
	[super setUp];
	
	graph = [[ZKMORGraph alloc] init];
	mixer = [[ZKMORMixerMatrix alloc] init];
	noise = [[ZKMORWhiteNoise alloc] init];
	simulator = [[ZKMORRenderSimulator alloc] init];
}

- (void)tearDown
{
	[simulator release];
	[noise release];
	[mixer release];
	[graph release];
	
	[super tearDown];
}

- (void)resetRenderingState
{
	wasPreRenderCalled = NO;
	wasPostRenderCalled = NO;
	wereNotificationsCalledAfterRemoval = NO;
	wereNotificationsCalledInOrder = YES;
	callNumber = 0;
}

- (void)verifyRenderingState
{
//	float postAveragePower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postAveragePower];
	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertNil([simulator error], @"Pulling on the graph encountered an error %@", [simulator error]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the graph was silent");
	
	STAssertTrue(wasPreRenderCalled, @"The pre-render function was never called");	
	STAssertTrue(wasPostRenderCalled, @"The post-render function was never called");
	STAssertTrue(wereNotificationsCalledInOrder, @"The render notifications were not called in order");
	STAssertFalse(wereNotificationsCalledAfterRemoval, @"The render notifications were called after being removed");
}

- (void)testReading
{	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// turn on metering so we can check output power
	[mixer setMeteringOn: YES];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph addRenderNotification: GraphTestRenderNotification refCon: self];		
		[graph initialize];
	[graph endPatching];
	
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];	

	// start playing
	[graph start];
	[self resetRenderingState];
	callNumber = 0;
	[simulator simulateNumCalls: 1 numFrames: 512 bus: 0];
	callNumber = 1;
	[graph removeRenderNotification: GraphTestRenderNotification refCon: self];
	
	[simulator simulateNumCalls: 99	numFrames: 512 bus: 0];
		
	[self verifyRenderingState];
	

	// stop playing
	[graph stop];
}

- (void)testRemoving
{
	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: [[noise outputBusAtIndex: 0] streamFormat]];
	
		// turn on metering so we can check output power
	[mixer setMeteringOn: YES];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph addRenderNotification: GraphTestRenderNotification refCon: self];
		[graph initialize];		
	[graph endPatching];
	
	STAssertTrue([noise retainCount] == 2, @"The noise's retain count should be 2 not %u", [noise retainCount]);	
	[graph removeDependentConduit: noise];	
	STAssertTrue([noise retainCount] == 1, @"The noise's retain count should be 1 not %u", [noise retainCount]);
	
	[simulator setConduit: graph];
	[graph initialize];
	
	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];	

	// start playing
	[graph start];
	
	[self resetRenderingState];
	
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];
		
//	float postAveragePower = [mixer postAveragePowerForOutput: 0];
	float postPeakHoldLevelPower = [mixer postPeakHoldLevelPowerForOutput: 0];
	
	STAssertNil([simulator error], @"Pulling on the graph encountered an error %@", [simulator error]);
		// make sure that the peak level was greater than silence
	STAssertFalse(postPeakHoldLevelPower > -120.f, @"The output of the graph should have been silent");
	
	STAssertTrue(wasPreRenderCalled, @"The pre-render function was never called");	
	STAssertTrue(wasPostRenderCalled, @"The post-render function was never called");
	STAssertTrue(wereNotificationsCalledInOrder, @"The render notifications were not called in order");
	STAssertFalse(wereNotificationsCalledAfterRemoval, @"The render notifications were called after being removed");


	// stop playing
	[graph stop];
}

- (void)testRelease
{
	// create a graph internal to this method
	ZKMORGraph* myGraph = [[ZKMORGraph alloc] init];
	ZKMORMixerMatrix* myMixer = [[ZKMORMixerMatrix alloc] init];
	ZKMORWhiteNoise* myNoise = [[ZKMORWhiteNoise alloc] init];
			
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[myNoise outputBusAtIndex: 0] streamFormat];
	[[myMixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// initialize everything
	[myNoise initialize];
	[myMixer initialize];
	
	// create a graph
	[myGraph beginPatching];
		[myGraph setHead: myMixer];
		[myGraph patchBus: [myNoise outputBusAtIndex: 0] into: [myMixer inputBusAtIndex: 0]];
	[myGraph endPatching];

		// the retain count for the mixer and noise should be incremented, plus they are dependents of the graph
	STAssertTrue([myMixer retainCount] == 2, @"The mixer's retain count should be 2 not %i", [myMixer retainCount]);
	STAssertTrue([myNoise retainCount] == 2, @"The noise's retain count should be 2 not %i", [myNoise retainCount]);

	[myGraph release];
	
	STAssertTrue([myMixer retainCount] == 1, @"The mixer's retain count should be 1 not %i", [myMixer retainCount]);
	STAssertTrue([myNoise retainCount] == 1, @"The noise's retain count should be 1 not %i", [myNoise retainCount]);


	[myMixer release];
	[myNoise release];	
}

- (void)testNullValues
{
	// patch nil into the input bus (shouldn't crash)
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: nil into: [mixer inputBusAtIndex: 0]];
		[graph initialize];		
	[graph endPatching];
	
	// patch nil into the input bus (shouldn't crash)
	[graph beginPatching];
		[graph setHead: mixer];
		[graph disconnectOutputToInputBus: [mixer inputBusAtIndex: 0]];
		[graph initialize];		
	[graph endPatching];
}

- (void)testSampleRateUpdate
{
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: [[noise outputBusAtIndex: 0] streamFormat]];
	
		// turn on metering so we can check output power
	[mixer setMeteringOn: YES];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph 
			patchBus: [noise outputBusAtIndex: 0]
			into: [mixer inputBusAtIndex: 0]];
		[graph addRenderNotification: GraphTestRenderNotification refCon: self];
		[graph initialize];
	[graph endPatching];
	[simulator setConduit: graph];
	
	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];
	
	[graph setGraphSampleRate: 48000.];

	// start playing
	[graph start];
	[self resetRenderingState];
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];
	[self verifyRenderingState];
	
	STAssertEquals(48000.0, [[mixer outputBusAtIndex: 0] sampleRate], 
		@"The Mixer's output sample rate is %.2f, not 48000.0", [[mixer outputBusAtIndex: 0] sampleRate]);
	STAssertEquals(48000.0, [[mixer inputBusAtIndex: 0] sampleRate], 
		@"The Mixer's input sample rate is %.2f, not 48000.0", [[mixer inputBusAtIndex: 0] sampleRate]);
	STAssertEquals(48000.0, [[noise outputBusAtIndex: 0] sampleRate], 
		@"The Reader's output sample rate is %.2f, not 48000.0", [[noise outputBusAtIndex: 0] sampleRate]);	

	// stop playing
	[graph stop];
}

- (void)testNumberOfChannelsUpdate
{
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// start off output stereo -- this will be changed
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 2);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// turn on metering so we can check output power
	[mixer setMeteringOn: YES];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph addRenderNotification: GraphTestRenderNotification refCon: self];
		[graph initialize];		
	[graph endPatching];
	[simulator setConduit: graph];
	
	STAssertEquals((unsigned) 2, [[graph outputBusAtIndex: 0] numberOfChannels], 
		@"The graph's output number of channels is %u, not 2", [[graph outputBusAtIndex: 0] numberOfChannels]);
	
	[graph uninitialize];
	[mixer uninitialize];
	
	// change to mono
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	[graph initialize];
	
	STAssertEquals((unsigned) 1, [[graph outputBusAtIndex: 0] numberOfChannels], 
		@"The graph's output number of channels is %u, not 1", [[graph outputBusAtIndex: 0] numberOfChannels]);
	
	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
	[graph start];
	[self resetRenderingState];
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];
	[self verifyRenderingState];

	// stop playing
	[graph stop];
}

- (void)testMaxFramesPerSlice
{	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// turn on metering so we can check output power
	[mixer setMeteringOn: YES];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph setMaxFramesPerSlice: 2048];
		[graph initialize];
	[graph endPatching];
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];	

	// start playing
	[graph start];
	[self resetRenderingState];
	[simulator simulateNumCalls: 100 numFrames: 2048 bus: 0];
		
	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		
	STAssertNil([simulator error], @"Pulling on the graph encountered an error %@", [simulator error]);
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the graph was silent");
	

	// stop playing
	[graph stop];
}

- (void)testSubGraphPlaying
{	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[noise outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// turn on metering so we can check output power
	[mixer setMeteringOn: YES];
	
	ZKMORGraph* subGraph = [[ZKMORGraph alloc] init];
	// create the subgraph
	[subGraph beginPatching];
		[subGraph setHead: mixer];
		[subGraph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
	[subGraph endPatching];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: subGraph];
		[graph addRenderNotification: GraphTestRenderNotification refCon: self];
		[graph initialize];
	[graph endPatching];
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];	

	// start playing
	[graph start];
	[self resetRenderingState];
	callNumber = 0;
	[simulator simulateNumCalls: 1 numFrames: 512 bus: 0];
	callNumber = 1;
	[graph removeRenderNotification: GraphTestRenderNotification refCon: self];
	
	[simulator simulateNumCalls: 99	numFrames: 512 bus: 0];
		
	[self verifyRenderingState];
	

	// stop playing
	[graph stop];
	[subGraph release];
}

@end
