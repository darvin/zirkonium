//
//  ZKMORMixer3DTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 24.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORMixer3DTest.h"
#import "ZKMORLogger.h"


@implementation ZKMORMixer3DTest

- (void)setUp
{
	mixer3D = [[ZKMORMixer3D alloc] init];
}

- (void)tearDown
{
	[mixer3D release];
}

- (void)testMixer3D
{
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	// try to log it
	[mixer3D logDebug];
	ZKMORLoggerSetIsLogging(NO);
	
	// verify the default stream format
	AudioStreamBasicDescription streamFormat = [[mixer3D outputBusAtIndex: 0] streamFormat];
	STAssertEquals(streamFormat.mSampleRate, ZKMORDefaultSampleRate(), @"Sample rate should be the default");
	STAssertEquals(streamFormat.mChannelsPerFrame, (UInt32) ZKMORDefaultNumberChannels(), @"Number of channels should be the default");
	
	STAssertNoThrow([mixer3D setMaxFramesPerSlice: 2048], @"Set max frames per slice should not cause an error");
	[mixer3D graphSampleRateChanged: 96000.];
	streamFormat = [[mixer3D outputBusAtIndex: 0] streamFormat];
	STAssertEquals(streamFormat.mSampleRate, 96000., @"Sample rate should have been changed.");
	
	STAssertNoThrow([mixer3D initialize], @"Initialize should not throw an exception");


	STAssertNoThrow([mixer3D uninitialize], @"Uninitialize should not throw an exception");
}

@end
