//
//  ZKMNRSpeakerLayoutSimulatorTest.m
//  Syncretism
//
//  Created by Chandrasekhar Ramakrishnan on 20.12.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMNRSpeakerLayoutSimulatorTest.h"


@implementation ZKMNRSpeakerLayoutSimulatorTest
- (void)setUp
{
	[super setUp];
	speakerSimulator = [[ZKMNRSpeakerLayoutSimulator alloc] init];
	fileOutput = [[ZKMORAudioFileOutput alloc] init];
	pinkNoise = [[ZKMORPinkNoise alloc] init];
}

- (void)tearDown
{
	[speakerSimulator release];
	[pinkNoise release];
	[fileOutput release];
	[super tearDown];

}

- (ZKMNRSpeakerLayout *)fiveDot0Layout
{
	NSMutableArray* speakers = [NSMutableArray arrayWithCapacity: 5];

	// set speaker positions
	ZKMNRSphericalCoordinate	coord = { 0.f, 0.f, 1.f };
	ZKMNRSpeakerPosition*		position;
	
	// left front
	coord.azimuth = 30.f / 180.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];

				
	// right front
	coord.azimuth = -30.f / 180.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	// center
	coord.azimuth = 0.f;
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	// left rear
	coord.azimuth = 110.f / 180.f;		
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
				
	// right rear
	coord.azimuth = -110.f / 180.f;		
	position = [[ZKMNRSpeakerPosition alloc] init];
	[position setCoordPhysical: coord];
	[position computeCoordPlatonicFromPhysical];
	[speakers addObject: position];
	[position release];
	
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setSpeakerLayoutName: @"5.0"];
	[layout setSpeakerPositionRings: [NSArray arrayWithObject: speakers]];
	return [layout autorelease];
}

- (void)testSpeakerLayoutSimulator
{
	[speakerSimulator setSpeakerLayout: [self fiveDot0Layout]];
	[speakerSimulator setSimulationMode: kZKMNRSpeakerLayoutSimulationMode_Headphones];

	AudioStreamBasicDescription streamFormat = [[pinkNoise outputBusAtIndex: 0] streamFormat];
			// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[pinkNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	[mixer setNumberOfOutputBuses: 5];
	
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 1] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 2] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 3] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 4] setStreamFormat: streamFormat];

	// create a graph
	ZKMORMixer3D* mixer3D = [speakerSimulator mixer3D];
	[graph beginPatching];
		[graph setHead: mixer3D];
		[graph patchBus: [pinkNoise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		
			// patch the mixer into the simulator
		[graph patchBus: [mixer outputBusAtIndex: 0] into: [mixer3D inputBusAtIndex: 0]];
		[graph patchBus: [mixer outputBusAtIndex: 1] into: [mixer3D inputBusAtIndex: 1]];
		[graph patchBus: [mixer outputBusAtIndex: 2] into: [mixer3D inputBusAtIndex: 2]];
		[graph patchBus: [mixer outputBusAtIndex: 3] into: [mixer3D inputBusAtIndex: 3]];
		[graph patchBus: [mixer outputBusAtIndex: 4] into: [mixer3D inputBusAtIndex: 4]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setGraph: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToDiagonalLevels];

	// start playing
	[simulator start];
	[simulator simulateNumCalls: 100 numFrames: 512];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the pink noise was silent");
	
	[simulator stop];
}

- (void)testRecord16BitAIFF
{
	NSError* error = nil;
	AudioStreamBasicDescription formatDesc;
	memset(&formatDesc, 0, sizeof(formatDesc));
	[ZKMORAudioFileRecorder getAIFFInt16Format: &formatDesc channels: 2];
	[fileOutput setFilePath: [self scratchTestFilePath] fileType: kAudioFileAIFFType dataFormat: formatDesc error: &error];
	STAssertNil(error, @"Set file path failed %@", error);
	if (error) {
		[self deleteScratchFile];
		return;
	}
	
	// create a graph
	AudioStreamBasicDescription streamFormat = [[pinkNoise outputBusAtIndex: 0] streamFormat];
			// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[pinkNoise outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	[mixer setNumberOfOutputBuses: 5];
	
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 1] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 2] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 3] setStreamFormat: streamFormat];
	[[mixer outputBusAtIndex: 4] setStreamFormat: streamFormat];

	// create a graph
	ZKMORMixer3D* mixer3D = [speakerSimulator mixer3D];
	[speakerSimulator setSpeakerLayout: [self fiveDot0Layout]];
	[speakerSimulator setSimulationMode: kZKMNRSpeakerLayoutSimulationMode_Headphones];	
	[graph beginPatching];
		[graph setHead: mixer3D];
		[graph patchBus: [pinkNoise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		
			// patch the mixer into the simulator
		[graph patchBus: [mixer outputBusAtIndex: 0] into: [mixer3D inputBusAtIndex: 0]];
		[graph patchBus: [mixer outputBusAtIndex: 1] into: [mixer3D inputBusAtIndex: 1]];
		[graph patchBus: [mixer outputBusAtIndex: 2] into: [mixer3D inputBusAtIndex: 2]];
		[graph patchBus: [mixer outputBusAtIndex: 3] into: [mixer3D inputBusAtIndex: 3]];
		[graph patchBus: [mixer outputBusAtIndex: 4] into: [mixer3D inputBusAtIndex: 4]];
		[graph initialize];
	[graph endPatching];
	
	[fileOutput setGraph: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToDiagonalLevels];

	// start playing
	[fileOutput start];
	unsigned i;
	for (i = 0; i < 100; i++) {
		[fileOutput runIteration: 512];
//		[fileOutput runIteration: 1152];
	}

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio file player was silent");
	
	[fileOutput stop];
	[self verifyScratchFile];
	[self deleteScratchFile];
}

@end
