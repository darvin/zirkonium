//
//  ZKMORFileReaderTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 11.09.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORFileReaderTest.h"
#import <Sycamore/ZKMORFileStreamer.h>
#import <Sycamore/ZKMORLogPrinter.h>
#import "AUOutputBL.h"


@implementation ZKMORFileReaderTest

- (void)testFileReader
{
	ZKMORFileReader* reader = new ZKMORFileReader(3, 4096);
//	ZKMORFileReader* reader = new ZKMORFileReader(8, 4096);
	reader->SetFilePath([[self mp3TestFilePath] UTF8String]);

	UInt32 numFrames = 1152;
	AUOutputBL aubl(reader->GetClientDataFormat(), numFrames);
	aubl.Allocate(numFrames);
	unsigned i, count = 25;
	float rmssum = 0.f;
	for (i = 0; i < count; ++i) {
		aubl.Prepare();
		AudioBufferList* abl = aubl.ABL();
		reader->PullBuffer(numFrames, abl);
		rmssum += ZKMORBufferListChannelRMS(abl, 0);
		if (10 == i) {
			reader->SetCurrentPosition(0.5);
		}
		usleep(1 * 1000 * 100);
	}
	aubl.Allocate(0);
	STAssertTrue(rmssum > 0.f, @"The ZKMORFileReader pulled silence");
}

@end
