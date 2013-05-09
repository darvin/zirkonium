//
//  ZKMORMixerMatrixTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 25.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORMixerMatrixTest.h"


@implementation ZKMORMixerMatrixTest

- (void)setUp
{
	mixer = [[ZKMORMixerMatrix alloc] init];
}

- (void)tearDown
{
	[mixer release];
}

- (void)testMixer
{
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	// try to log it
	[mixer logDebug];
	ZKMORLoggerSetIsLogging(NO);
	
	// verify the default stream format
	AudioStreamBasicDescription streamFormat = [[mixer outputBusAtIndex: 0] streamFormat];
	STAssertEquals(streamFormat.mSampleRate, ZKMORDefaultSampleRate(), @"Sample rate should be the default");
	STAssertEquals(streamFormat.mChannelsPerFrame, (UInt32) ZKMORDefaultNumberChannels(), @"Number of channels should be the default");
	
	STAssertNoThrow([mixer setMaxFramesPerSlice: 2048], @"Set max frames per slice should not cause an error");
	[mixer graphSampleRateChanged: 96000.];
	streamFormat = [[mixer outputBusAtIndex: 0] streamFormat];
	STAssertEquals(streamFormat.mSampleRate, 96000., @"Sample rate should have been changed.");
	
	[mixer setNumberOfOutputBuses: 3];
	
	STAssertNoThrow([mixer initialize], @"Initialize should not throw an exception");


	STAssertNoThrow([mixer uninitialize], @"Uninitialize should not throw an exception");
}

@end
