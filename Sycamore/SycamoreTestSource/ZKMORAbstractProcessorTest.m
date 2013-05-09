//
//  ZKMORAbstractProcessorTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 29.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORAbstractProcessorTest.h"


@implementation ZKMORAbstractProcessorTest

- (void)setUp
{
	ZKMORLogPrinterClear();
	
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	
	graph = [[ZKMORGraph alloc] init];
	mixer = [[ZKMORMixerMatrix alloc] init];
	noise = [[ZKMORWhiteNoise alloc] init];
	simulator = [[ZKMORRenderSimulator alloc] init];
	
	[mixer setMeteringOn: YES];
}

- (void)tearDown
{
	[noise release];
	[graph release];
	[mixer release];
	[simulator release];
	ZKMORLogPrinterClear();
	ZKMORLoggerSetIsLogging(NO);
}

- (NSString *)dirPathForTestFiles
{
		// some gymnastics to find the directory with example files
	NSBundle* theBundle = [NSBundle bundleForClass: [self class]];
	NSString* filePath;
	if ([@"octest" isEqualToString: [[theBundle bundlePath] pathExtension]]) {
		// we are in an ocunit bundle
		NSString* directoryPath = [[theBundle bundlePath] stringByDeletingLastPathComponent];
		filePath = 
			[directoryPath stringByAppendingPathComponent: @"../../examplefiles/"];
	} else 
		filePath = @"../../examplefiles/";	

	return filePath;
}

- (NSString *)mp3TestFilePath { return [[self dirPathForTestFiles] stringByAppendingPathComponent: @"Kiku.mp3"]; }

- (NSString *)aiffTestFilePath { return [[self dirPathForTestFiles] stringByAppendingPathComponent: @"1234.aiff"]; }

- (NSString *)scratchTestFilePath { return [[self dirPathForTestFiles] stringByAppendingPathComponent: @"scratch.aiff"]; }

	// this is a test, but I want to call it myself, so don't use the word test in the name
- (void)verifyScratchFile
{
	ZKMORAudioFile*	myFile = [[ZKMORAudioFile alloc] init];
	ZKMORGraph* myGraph = [[ZKMORGraph alloc] init];
	ZKMORMixerMatrix* myMixer = [[ZKMORMixerMatrix alloc] init];
	ZKMOROutputSimulator* mySimulator = [[ZKMOROutputSimulator alloc] init];
	
	[myMixer setMeteringOn: YES];
	
	[myFile setFilePath: [self scratchTestFilePath] error: nil];
	// set up stream formats -- this needs to be done before initialization
	AudioStreamBasicDescription streamFormat = [[myFile outputBusAtIndex: 0] streamFormat];
	[[myMixer inputBusAtIndex: 0] setStreamFormat: streamFormat];
	
		// make the output mono -- makes it easier to check output power
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 1);
	[[myMixer outputBusAtIndex: 0] setStreamFormat: streamFormat];
	
	// create a graph
	[myGraph beginPatching];
		[myGraph setHead: myMixer];
		[myGraph patchBus: [myFile outputBusAtIndex: 0] into: [myMixer inputBusAtIndex: 0]];
		[myGraph initialize];
	[myGraph endPatching];
	
	[mySimulator setGraph: myGraph];

	// the mixer starts out with all levels at 0 -- set them to something useful
	[myMixer setToCanonicalLevels];

	// start playing
	Float64 startTime = [[mySimulator clock] currentTimeSeconds];
	[mySimulator start];
	[mySimulator simulateNumCalls: 100 numFrames: 512];
	Float64 endTime = [[mySimulator clock] currentTimeSeconds];	

	float postPeakHoldLevelPower = [(ZKMORMixerMatrixOutputBus *) [myMixer outputBusAtIndex: 0] postPeakHoldLevelPower];
		// make sure that the peak level was greater than silence
	STAssertTrue(postPeakHoldLevelPower > -120.f, @"The output of the audio file was silent");
	
	STAssertTrue(endTime - startTime > 0.5, @"The clock should have advanced while simulating");
	[mySimulator stop];
	
	[myFile release];
	[myGraph release];
	[myMixer release];
	[mySimulator release];
}

- (void)deleteScratchFile
{
	[[NSFileManager defaultManager] 
		removeFileAtPath: [self scratchTestFilePath]  
		handler: nil];	
}

@end
