//
//  ZKMORAudioFileOutputTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 02.10.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioFileOutputTest.h"


@implementation ZKMORAudioFileOutputTest

- (void)setUp
{
	[super setUp];
	fileOutput = [[ZKMORAudioFileOutput alloc] init];
}

- (void)tearDown
{
	[fileOutput release];
	[super tearDown];
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
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
		[graph initialize];
	[graph endPatching];
	
	[fileOutput setGraph: graph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[mixer setToCanonicalLevels];

	// start playing
	[fileOutput start];
	unsigned i;
	for (i = 0; i < 100; i++) {
		[fileOutput runIteration: 512];
	}

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [mixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio file player was silent");
	
	[fileOutput stop];
	[self verifyScratchFile];
	[self deleteScratchFile];
}

@end
