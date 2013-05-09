//
//  ZKMORAudioFileRecorderTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 15.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioFileRecorderTest.h"


@implementation ZKMORAudioFileRecorderTest


- (void)setUp
{
	[super setUp];
	fileRecorder = [[ZKMORAudioFileRecorder alloc] init];
}

- (void)tearDown
{
	[fileRecorder release];
	[super tearDown];
}

	// this is a test, but I want to call it myself, so don't use the word test in the name
- (void)record16BitAIFF
{
	NSError* error = nil;
	AudioStreamBasicDescription formatDesc;
	memset(&formatDesc, 0, sizeof(formatDesc));
	[ZKMORAudioFileRecorder getAIFFInt16Format: &formatDesc channels: 2];
	[fileRecorder setFilePath: [self scratchTestFilePath] fileType: kAudioFileAIFFType dataFormat: formatDesc error: &error];
	STAssertNil(error, @"Set file path failed %@", error);
	if (error) {
		[self deleteScratchFile];
		return;
	}
	
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[fileRecorder outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [fileRecorder outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [fileRecorder inputBusAtIndex: 0]];
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
	[fileRecorder flushAndClose];
	[self deleteScratchFile];
}

	// this is a test, but I want to call it myself, so don't use the word test in the name
- (void)recordJunk
{
	NSError* error = nil;
	AudioStreamBasicDescription formatDesc; 
	[ZKMORAudioFileRecorder getAIFFInt16Format: &formatDesc channels: 2];	
	[fileRecorder setFilePath: @"non-existant-dir/non-existant-file.wav" fileType: kAudioFileAIFFType dataFormat: formatDesc error: &error];
	STAssertNotNil(error, @"Openeing a non-existant fileRecorder should have produced an error");
}

	// this is a test, but I want to call it myself, so don't use the word test in the name
- (void)record32BitAIFC
{
	AudioStreamBasicDescription formatDesc;
	memset(&formatDesc, 0, sizeof(formatDesc));
	[ZKMORAudioFileRecorder getAIFCFloat32Format: &formatDesc channels: 2];
	[fileRecorder setFilePath: [self scratchTestFilePath] fileType: kAudioFileAIFCType dataFormat: formatDesc error: nil];

	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[fileRecorder outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [fileRecorder outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [fileRecorder inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setInputsAndOutputsOn];
	[mixer setToCanonicalLevels];

	// start playing
	[graph start];
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio fileRecorder was silent");
	
	[graph stop];
	[fileRecorder flushAndClose];
	[self verifyScratchFile];
	[self deleteScratchFile];
}

	// this is a test, but I want to call it myself, so don't use the word test in the name
- (void)record16BitWAVE
{
	AudioStreamBasicDescription formatDesc;
	memset(&formatDesc, 0, sizeof(formatDesc));
	[ZKMORAudioFileRecorder getWAVEInt16Format: &formatDesc channels: 2];
	[fileRecorder setFilePath: [self scratchTestFilePath] fileType: kAudioFileWAVEType dataFormat: formatDesc error: nil];

	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[fileRecorder outputBusAtIndex: 0] streamFormat];
	[[mixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[mixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [fileRecorder outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [fileRecorder inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[simulator setConduit: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setInputsAndOutputsOn];
	[mixer setToCanonicalLevels];

	// start playing
	[graph start];
	[simulator simulateNumCalls: 100 numFrames: 512 bus: 0];

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio fileRecorder was silent");
	
	[graph stop];
	[fileRecorder flushAndClose];
	[self verifyScratchFile];
	[self deleteScratchFile];
}

- (void)testRecording
{
	// this tests changing the file name and type of an existing file recorder
	[self record16BitAIFF];
	[self recordJunk];
	[mixer uninitialize];
	[self record32BitAIFC];
}

- (void)testRecordWave
{
	// this tests changing the file name and type of an existing file recorder
	[self record16BitWAVE];
}

- (void)testAddFileRecorderAsDependent
{
	[graph addDependentConduit: fileRecorder];
}

- (void)testSetFilePath
{
	STAssertThrows([fileRecorder setFilePath: [self scratchTestFilePath] error: nil], @"File recorder should not implement setFilePath:");
}

@end
