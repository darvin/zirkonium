//
//  ZKMRNHALPlugInTest.m
//  Zirkonium
//
//  Created by C. Ramakrishnan on 24.04.07.
//  Copyright 2007 Illposed Software. All rights reserved.
//

#import "ZKMRNHALPlugInTest.h"

// Much of the code is copied from PortAudio, so we need this macro
#define ERR_WRAP(mac_err) do { result = mac_err ; line = __LINE__ ; if ( result != noErr ) goto error ; } while(0)
#define INPUT_ELEMENT  (1)
#define OUTPUT_ELEMENT (0)

static OSStatus AudioIOProc( void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData )
{
	ZKMRNHALPlugInTest* THIS = (ZKMRNHALPlugInTest *) inRefCon;
	THIS->didInputCallbackRun = YES;
	return noErr;
}

@implementation ZKMRNHALPlugInTest

- (void)testZirkoniumDevice
{
	ZKMORDeviceOutput* deviceOutput =  [[ZKMORDeviceOutput alloc] init];
	ZKMORAudioUnit* outputUnit = [deviceOutput outputUnit];
	AudioUnit audioUnit = [outputUnit audioUnit];
	
	// set up the output unit
    OSErr result = noErr;
    int line = 0;
	didInputCallbackRun = NO;
	
		// enable input
	{
		UInt32 enableIO;
		enableIO = 1;
		ERR_WRAP( AudioUnitSetProperty(audioUnit,
				 kAudioOutputUnitProperty_EnableIO,
				 kAudioUnitScope_Input,
				 INPUT_ELEMENT,
				 &enableIO,
				 sizeof(enableIO) ) );
	}
	
		// disable output
    {
		UInt32 enableIO;
		enableIO = 0;
		ERR_WRAP( AudioUnitSetProperty( audioUnit,
				 kAudioOutputUnitProperty_EnableIO,
				 kAudioUnitScope_Output,
				 OUTPUT_ELEMENT,
				 &enableIO,
				 sizeof(enableIO) ) );
    }
		// add an input callback
	AURenderCallbackStruct rcbs;
    rcbs.inputProc = AudioIOProc;
    rcbs.inputProcRefCon = self;
    ERR_WRAP( AudioUnitSetProperty(
                               audioUnit,
                               kAudioOutputUnitProperty_SetInputCallback,
                               kAudioUnitScope_Output,
                               INPUT_ELEMENT,
                               &rcbs,
                               sizeof(rcbs)) );
	
	AudioUnitInitialize(audioUnit);
	AudioOutputUnitStart(audioUnit);
		// sleep to let the callback run
	sleep(1);
//  Check that the AU is indeed running
	UInt32 isRunning;
	UInt32 dataSize = sizeof(isRunning);
	AudioUnitGetProperty(audioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &isRunning, &dataSize);
	STAssertTrue(isRunning, @"Output unit not running");
	AudioOutputUnitStop(audioUnit);
	
error:
	STAssertTrue(didInputCallbackRun, @"Input callback should have run");
	[deviceOutput release];
}

@end
