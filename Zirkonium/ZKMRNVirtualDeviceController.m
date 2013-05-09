//
//  ZKMRNVirtualDeviceController.m
//  Zirkonium
//
//  Created by Jens on 22.10.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ZKMRNVirtualDeviceController.h"
static void print_stream_info (AudioStreamBasicDescription *stream)
{
  printf ("  mSampleRate = %f\n", stream->mSampleRate);
  printf ("  mFormatID = '%c%c%c%c'\n",
	  (char) (stream->mFormatID >> 24) & 0xff,
	  (char) (stream->mFormatID >> 16) & 0xff,
	  (char) (stream->mFormatID >> 8) & 0xff,
	  (char) (stream->mFormatID >> 0) & 0xff);

  printf ("  mFormatFlags: 0x%lx\n", stream->mFormatFlags);
  
#define doit(x) if (stream->mFormatFlags & x) { printf ("    " #x " (0x%x)\n", x); }
  doit (kAudioFormatFlagIsFloat);
  doit (kAudioFormatFlagIsBigEndian);
  doit (kAudioFormatFlagIsSignedInteger);
  doit (kAudioFormatFlagIsPacked);
  doit (kAudioFormatFlagIsAlignedHigh);
  doit (kAudioFormatFlagIsNonInterleaved);
  doit (kAudioFormatFlagsAreAllClear);
#undef doit

#define doit(x) printf ("  " #x " = %ld\n", stream->x)
  doit (mBytesPerPacket);
  doit (mFramesPerPacket);
  doit (mBytesPerFrame);
  doit (mChannelsPerFrame);
  doit (mBitsPerChannel);
#undef doit
}


@implementation ZKMRNVirtualDeviceController

-(id)init
{
	if(self=[super init]) {
		_isInitialized = NO;
		_isRunning = NO; 
		
		_virtualDeviceOutput = [[ZKMORDeviceOutput alloc] init];
		_virtualGraph = [[ZKMORGraph alloc] init];
		_virtualMixer = [[ZKMORMixerMatrix alloc] init];
		[_virtualMixer setMeteringOn:YES]; 

		[self initialize];
	}
	return self; 
}

-(void)dealloc
{
	if(_virtualDeviceOutput)
		[_virtualDeviceOutput release];
	if(_virtualGraph)
		[_virtualGraph release];
	if(_virtualMixer)
		[_virtualMixer release];
	[super dealloc];
}

-(void)initialize
{
	if(_isInitialized) return;
	
	// SET VIRTUAL DEVICE ...
	for(ZKMORAudioDevice* aDevice in [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] outputDevices]) {
		if([@"Apple Inc.:Zirkonium Aggregate Device"/*@"ZKM:Zirkonium Kernel Extension"/*@"ZKM:Zirkonium (2 channels)"*/ isEqualToString:[aDevice audioDeviceDescription]]) {
			NSError* error = nil;
			[_virtualDeviceOutput setOutputDevice:aDevice error:&error];
			if(error) { NSLog(@"Error with Virtual Device"); return; }
		}
	}
	
	// SET BUS COUNT ...
	//[_virtualMixer setNumberOfOutputBuses:1];
	//[_virtualMixer setNumberOfInputBuses:1];
	
	//STREAM FORMAT
	AudioStreamBasicDescription streamFormat = [[[_virtualDeviceOutput deviceInput] outputBusAtIndex:0] streamFormat];
	//ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, 2);
	
	//[[_virtualMixer inputBusAtIndex:0] setStreamFormat:streamFormat];
	//[[_virtualMixer outputBusAtIndex:0] setStreamFormat:streamFormat]; 
	
	// PATCH GRAPH ...
	[_virtualGraph beginPatching];
		[_virtualGraph uninitialize];
		[_virtualGraph setHead: _virtualMixer]; 
		[_virtualGraph patchBus: [[_virtualDeviceOutput deviceInput] outputBusAtIndex:0] into: [_virtualMixer inputBusAtIndex: 0]];
		[_virtualGraph initialize];
	[_virtualGraph endPatching];
	
	NSLog(@"VIRTUAL DEVICE: %@", _virtualDeviceOutput);
	NSLog(@"VIRTUAL DEVICE INPUT: %@", [_virtualDeviceOutput deviceInput]);	
	NSLog(@"VIRTUAL MIXER: %@", _virtualMixer);	
	NSLog(@"VIRTUAL STREAM FORMAT:");
	print_stream_info(&streamFormat);

	
	// OWNERSHIP TO GRAPH ...
	[_virtualMixer release];
	[_virtualDeviceOutput setGraph: _virtualGraph];
	[_virtualMixer setInputsAndOutputsOn];
	[_virtualMixer setToCanonicalLevels];	
	[_virtualGraph release];
	
	// SET DEBUG LEVELS ...
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	[_virtualGraph setDebugLevel: kZKMORDebugLevel_All];
	[_virtualGraph logDebug];
	
	_isInitialized = YES; 
}

#pragma mark -

-(void)startDevice
{
	if(_isInitialized && !_isRunning) {
		[_virtualDeviceOutput start];
		_isRunning = YES;
	}
}

-(void)stopDevice
{
	if(_isInitialized && _isRunning) {
		[_virtualDeviceOutput stop];
		_isRunning = NO;
	}
}

#pragma mark -

-(ZKMORGraph*)graph 
{
	return _virtualGraph; 
}

-(ZKMORDeviceInput*)deviceInput
{
	return [_virtualDeviceOutput deviceInput];
}



@end
