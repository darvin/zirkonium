//
//  ZKMORAudioFilePlayerParallelTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 30.01.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAudioFilePlayerParallelTest.h"
#include "AUOutputBL.h"
#include "CAAudioTimeStamp.h"


@implementation ZKMORAudioFilePlayerParallelTest
- (void)setUp
{
	[super setUp];
	filePlayer1 = [[ZKMORAudioFilePlayer alloc] init];
	filePlayer2 = [[ZKMORAudioFilePlayer alloc] init];
}

- (void)tearDown
{
	[filePlayer1 release];
	[filePlayer2 release];
	[super tearDown];
}

- (void)testReadingInParallel
{
	[filePlayer1 setFilePath: [self aiffTestFilePath] error: nil];
	[filePlayer2 setFilePath: [self aiffTestFilePath] error: nil];
	
	UInt32 numFrames = 512;
	unsigned numCalls = 100;
	AudioStreamBasicDescription streamDesc = [[filePlayer1 outputBusAtIndex: 0] streamFormat];
	CAStreamBasicDescription streamFormat(streamDesc);
	[[filePlayer1 outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	AUOutputBL aubl1(streamFormat, numFrames);
	aubl1.Allocate(numFrames);
	AUOutputBL aubl2(streamFormat, numFrames);
	aubl2.Allocate(numFrames);
	UInt32 flags = 0;
	CAAudioTimeStamp ts(0.0);
	
	ZKMORRenderFunction RenderFunc = [filePlayer1 renderFunction];
	
	for (unsigned counter = 0; counter < numCalls; counter++) {
		aubl1.Prepare();
		aubl2.Prepare();
		
		AudioBufferList* abl1 = aubl1.ABL();
		AudioBufferList* abl2 = aubl2.ABL();		
		
		OSStatus err;
		err = RenderFunc(filePlayer1, &flags, &ts, 0, numFrames, abl1);
		if (err) {
			STFail(@"Render filePlayer1 failed %i", err);
		}
		
		err = RenderFunc(filePlayer2, &flags, &ts, 0, numFrames, abl2);
		if (err) {
			STFail(@"Render filePlayer1 failed %i", err);
		}
		
			// compare buffers
		unsigned i, j;
		for (j = 0; j < abl1->mNumberBuffers; j++) {
			AudioBuffer* buffer1 = &abl1->mBuffers[j];
			AudioBuffer* buffer2 = &abl1->mBuffers[j];			
			for (i = 0; i < numFrames; i++) {
				float* samps1 = (float *) buffer1->mData;
				float* samps2 = (float *) buffer2->mData;
//				STAssertEqualsWithAccuracy(samps1[i], samps2[i], 0.000001
				STAssertEquals(samps1[i], samps2[i], @"Sample %u:%u are not equal (%.3f : %.3f)", j, i, samps1[i], samps2[i]);
			}
		}
		
		ts.mSampleTime += numFrames;
		// sleep briefly to let other threads run, if they need to
		usleep(1000);
	}
	
	// dispose of allocated memory
	aubl1.Allocate(0);
	aubl2.Allocate(0);	
}

@end
