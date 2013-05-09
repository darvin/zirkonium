//
//  ZKMORDebugTest.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 25.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//
//  First logs all the objects to make sure they produce reasonable logging info.
//

#import <Sycamore/Sycamore.h>


int main(int argc, char** argv)
{

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	
	// Log a few random objects
	id thingy = [[ZKMORConduit alloc] init];
	[thingy logDebug];
	[thingy initialize];
	[thingy logDebug];
	[thingy release];
	ZKMORLogPrinterFlush();
	
	thingy= [[ZKMORMixer3D alloc] init];
	[thingy logDebug];
	[thingy release];
	ZKMORLogPrinterFlush();
	
	thingy = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] defaultOutputDevice];
	[thingy logDebug];
	[thingy release];
	ZKMORLogPrinterFlush();
	

	// Run a graph a bit
	ZKMORMixerMatrix* mixer = [[ZKMORMixerMatrix alloc] init];
	[mixer logDebug];
	ZKMORLogPrinterFlush();
	
	ZKMORWhiteNoise* noise = [[ZKMORWhiteNoise alloc] init];
	[noise logDebug];
	ZKMORLogPrinterFlush();
	
	ZKMORGraph* graph = [[ZKMORGraph alloc] init];
//	[graph setDebugLevel: kZKMORDebugLevel_All];	
	[graph beginPatching];
		[graph setHead: mixer];
		[graph patchBus: [noise outputBusAtIndex: 0] into: [mixer inputBusAtIndex: 0]];
	[graph endPatching];
	ZKMORLogPrinterFlush();

	[mixer release];
	[noise release];
	[graph logDebug];
	ZKMORLogPrinterFlush();
	
	[graph initialize];
	[mixer setToCanonicalLevels];

	[graph setDebugLevel: kZKMORDebugLevel_PostRender];
	ZKMORRenderSimulator* sim = [[ZKMORRenderSimulator alloc] init];
	[sim setConduit: graph];
	[sim simulateNumCalls: 2 numFrames: 512 bus: 0];
	ZKMORLogPrinterFlush();
	
	[sim release];
	[graph release];
    [pool release];
    return 0;
}
