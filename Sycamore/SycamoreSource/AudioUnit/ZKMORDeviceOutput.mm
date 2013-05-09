//
//  ZKMORDeviceOutput.m
//  Sycamore
//
//  Created by Chandrasekhar Ramakrishnan on 30.08.06.
//  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMORDeviceOutput.h"
#import "ZKMORAudioUnit.h"
#import "ZKMORGraph.h"
#import "ZKMORLogger.h"
#import "ZKMORAudioHardwareSystem.h"
#import "ZKMORException.h"
#import "ZKMORClock.h"
#include "CAAudioHardwareSystem.h"
#include "CAAudioHardwareDevice.h"
#include "CAAudioUnitZKM.h"
#include "CAException.h"

NSString* const	ZKMORDeviceOutputDeviceWillDisappearNotification = @"ZKMORDeviceOutputDeviceWillDisappearNotification";
NSString* const	ZKMORDeviceOutputDeviceDidDisappearNotification = @"ZKMORDeviceOutputDeviceDidDisappearNotification";

@interface ZKMORDeviceOutput (ZKMORDeviceOutputPrivate)

- (void)startDeviceRunning;
- (void)stopDeviceRunning;
- (BOOL)createOutputUnitAndDevice;
- (void)deviceSampleRateChanged;
- (void)deviceSampleRateChanged:(NSNotification *)notification;
- (void)devicesChanged:(NSNotification *)notification;

@end

@interface ZKMORDeviceInput (ZKMORDeviceInputPrivate)

- (id)initWithDeviceOutput:(ZKMORDeviceOutput *)deviceOutput;
- (void)outputDeviceChanged;
- (CAAudioUnit *)outputCAAudioUnit;

@end

static void PrintMapData(SInt32* map, UInt32 mapCount, UInt32 elt)
{
	for (unsigned i = 0; i < mapCount; i++) {
		printf("%umap[%i] = %i ", elt, i, map[i]);
	}
	printf("\n");
}


static void PrintMap(CAAudioUnit* outputUnit, UInt32 elt)
{
	OSStatus err; UInt32 dataSize; Boolean writable;
		// kAudioUnitScope_Output and 1 come from TN2091
//	err = AudioUnitGetPropertyInfo(outputUnit->AU(), kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, elt, &dataSize, &writable);
	err = outputUnit->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, elt, &dataSize, &writable);
	if (err) {
		printf("Could not get size of map %i\n", err);
		return;
	}
	
	if (dataSize < 1) return;
		// how big is the channel map?
	UInt32 mapCount = dataSize / sizeof(SInt32);
	SInt32 map[mapCount];
    
	err = outputUnit->GetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, elt, map, &dataSize);
	if (err) {
		printf("Could not get map %i\n", err);
		return;
	}
	
	PrintMapData(map, mapCount, elt);
}

static OSStatus DeviceRenderFunction(	id							SELF,
										AudioUnitRenderActionFlags 	* ioActionFlags,
										const AudioTimeStamp 		* inTimeStamp,
										UInt32						inOutputBusNumber,
										UInt32						inNumberFrames,
										AudioBufferList				* ioData)
{
	//NSLog(@"Device Render Func");  

	ZKMORDeviceOutputStruct* deviceOutputStruct = (ZKMORDeviceOutputStruct*) SELF;
	ZKMORGraph* graph = deviceOutputStruct->_graph;
	
	OSStatus err = GraphRenderFunction(graph, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
	deviceOutputStruct->_lastError = err;

	return err;
}


@implementation ZKMORDeviceOutput

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
		// stops the device as well
	[self setOutputDevice: nil error: nil];
	if (_deviceInput) [_deviceInput release];
	if (_outputUnit) [_outputUnit release];
	[super dealloc];
}

- (id)init
{
	if (![super init]) return nil;
	
	if (![self createOutputUnitAndDevice]) {
		[self release]; 
		return nil;
	}
	
	AURenderCallbackStruct callback = { (AURenderCallback) DeviceRenderFunction, self };
	[_outputUnit setCallback: &callback busNumber: 0];
	
	_deviceInput = [[ZKMORDeviceInput alloc] initWithDeviceOutput: self];
	
	if ([self canDeliverInput]) {
		[self setInputEnabled: YES];
	}
	
	[self startDeviceRunning];
	
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(devicesChanged:) name: ZKMORAudioHardwareDevicesChangedNotification object: nil];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(deviceSampleRateChanged:) name: ZKMORAudioDeviceSampleRateChangedNotification object: nil];
	
	return self;
}

#pragma mark _____  ZKMORDeviceOutputPrivate
- (void)startDeviceRunning { [_outputDevice caAudioHardwareDevice]->StartIOProc(NULL); }
- (void)stopDeviceRunning { [_outputDevice caAudioHardwareDevice]->StopIOProc(NULL); }

- (BOOL)createOutputUnitAndDevice
{
	Component comp;
	ComponentDescription desc;
	AudioUnit copyOutput;
	
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_HALOutput;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent(NULL, &desc);
	if (comp == NULL) return NO;
	if (OpenAComponent(comp, &copyOutput)) return NO;
	
	_outputUnit = [[ZKMORAudioUnit alloc] initWithAudioUnit: copyOutput disposeWhenDone: YES];
	
	_outputDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] defaultOutputDevice];
	[_outputDevice retain];
	AudioDeviceID defaultDeviceID = [_outputDevice audioDeviceID];
	UInt32 dataSize = sizeof(AudioDeviceID);	
	[_outputUnit caAudioUnit]->SetProperty(kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &defaultDeviceID, dataSize);
	[_clock setTimebaseDeviceOutput: self];
	return YES;
}

- (void)deviceSampleRateChanged:(NSNotification *)notification
{
		// some other device may have changed -- only interested in the device I'm attached to
	if ([notification object] != _outputDevice) return;
	
	BOOL wasRunning = [self isRunning];
	if (wasRunning) [self stop];
	
	[_outputUnit uninitialize];
	ZKMORConduitBus* inputBus = [_outputUnit inputBusAtIndex: 0];
	[inputBus setSampleRate: [_outputDevice nominalSampleRate]];
	[[self deviceInput] outputDeviceChanged];		
	[_graph setGraphSampleRate: [_outputDevice nominalSampleRate]];
	[_outputUnit initialize];
}

- (void)devicesChanged:(NSNotification *)notification
{
	unsigned deviceIndex = CAAudioHardwareSystem::GetIndexForDevice([_outputDevice audioDeviceID]);
		// if the device still exists, we are ok
	if (deviceIndex < 0xFFFFFFFF) return;
		
		// set the output device to the new default device
	ZKMORAudioDevice* device = 
		[[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] 
			audioDeviceForDeviceID: CAAudioHardwareSystem::GetDefaultDevice(false, false)];
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMORDeviceOutputDeviceWillDisappearNotification object: self];
	[self setOutputDevice: device error: nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: ZKMORDeviceOutputDeviceDidDisappearNotification object: self];
}

- (void)setChannelMapSortedByPatchChannel:(NSArray*)channelMap
{
	//lazy
	if(!_channelMapSortedByPatchChannel) {
		_channelMapSortedByPatchChannel = [[NSArray arrayWithArray:channelMap] retain];
	} else {
		[_channelMapSortedByPatchChannel release];
		_channelMapSortedByPatchChannel = [[NSArray arrayWithArray:channelMap] retain];
	}
}



#pragma mark _____  Accessors
- (ZKMORAudioDevice *)outputDevice { return _outputDevice; }
- (BOOL)setOutputDevice:(ZKMORAudioDevice *)outputDevice error:(NSError **)error
{
	if (outputDevice == _outputDevice) return YES;
	[self willChangeValueForKey: @"outputDevice"];
	
	// Remove our property listener on the old device (don't abort if it fails)
	ZKMORAudioDevice* oldDevice = _outputDevice;
	[self stop];
	[_outputUnit uninitialize];
	
	try {
			// stop the old device if we were the ones who started it
		[self stopDeviceRunning];
	} catch (CAException& e) {
		OSStatus err = e.GetError();
			// the device dissappeared -- that's why we can't stop it
		if (kAudioHardwareBadDeviceError != err) ZKMORLogError(kZKMORLogSource_Hardware, CFSTR("%4.4s: Could not stop device %@"), &err, _outputDevice);
	}
	
	if (!outputDevice) {
		if (oldDevice) [oldDevice release];
		return YES;
	}
	
	// set the current device for the audio unit
	UInt32 dataSize = sizeof(AudioDeviceID);
	AudioDeviceID audioDeviceID = [outputDevice audioDeviceID];
	[_outputUnit caAudioUnit]->SetProperty(kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &audioDeviceID, dataSize);
	
	_outputDevice = outputDevice;
	[_outputDevice retain];

		// start the new device if it is not already running
	[self startDeviceRunning];
	
		// enable input if it can be enabled
	[self setInputEnabled: [self canDeliverInput]];
	
		// update anything depending on the current device
	ZKMORConduitBus* inputBus = [_outputUnit inputBusAtIndex: 0];
	[inputBus setSampleRate: [_outputDevice nominalSampleRate]];
	[[self deviceInput] outputDeviceChanged];
	[_graph setGraphSampleRate: [_outputDevice nominalSampleRate]];
	

	[_outputUnit initialize];

	if (oldDevice) [oldDevice release];

	[self didChangeValueForKey: @"outputDevice"];
	
	return YES;
}

- (float)volume 
{ 
	Float32 value;
	[_outputUnit caAudioUnit]->GetParameter(kHALOutputParam_Volume, kAudioUnitScope_Global, 0, value);
	return value;
} 
- (void)setVolume:(float)volume 
{ 
	Float32 value = volume;
	[_outputUnit caAudioUnit]->SetParameter(kHALOutputParam_Volume, kAudioUnitScope_Global, 0, value);
}

- (NSMutableArray *)channelMap
{
/*
	// find out how much space the channel map takes
	OSStatus err; UInt32 dataSize; Boolean writable;
	err = [_outputUnit caAudioUnit]->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, &dataSize, &writable);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetPropertyInfo ChannelMap, Output : %@", error);
	}
	
	if (dataSize < 1) return nil;

	// read the channel map
	UInt32 mapCount = dataSize / sizeof(SInt32);
	SInt32 map[mapCount];
	err = [_outputUnit caAudioUnit]->GetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, map, &dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Output : %@", error);
	}
	
	// convert the map to a Cocoa thing
	NSMutableArray* channelMap = [NSMutableArray arrayWithCapacity: mapCount];
	unsigned i;
	for (i = 0; i < mapCount; i++) {
		[channelMap addObject: [NSNumber numberWithInt: map[i]]];
	}

	return channelMap;
*/
	UInt32 mapCount = [self channelMapSize];
	SInt32 map[mapCount];
	[self getPrimitiveChannelMap: map size: mapCount];
	
	// convert the map to a Cocoa thing
	NSMutableArray* channelMap = [NSMutableArray arrayWithCapacity: mapCount];
	unsigned i;
	for (i = 0; i < mapCount; i++) {
		[channelMap addObject: [NSNumber numberWithInt: map[i]]];
	}

	return channelMap;
}

- (void)setChannelMap:(NSArray *)channelMap
{
/*
	// TODO -- Check that the channel map has the same number of channels as the output
	OSStatus err; UInt32 dataSize; Boolean writable; unsigned i;
	if (!channelMap) {
		err = [_outputUnit caAudioUnit]->SetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, NULL, 0);
		if (err) {
			NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
			ZKMORThrow(AudioUnitError, @"SetProperty to Null ChannelMap, Output : %@", error);
		}
		
		return;
	}
	
	// find out how much space the channel map takes
	err = [_outputUnit caAudioUnit]->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, &dataSize, &writable);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetPropertyInfo ChannelMap, Output : %@", error);
	}

	// read the channel map out of the NSArray into a C/C++ array
	UInt32 mapCount = dataSize / sizeof(SInt32);
	SInt32 map[mapCount];
	for (i = 0; i < mapCount; i++) map[i] = -1;
	
	UInt32 count = MIN(mapCount, [channelMap count]);
	for (i = 0; i < count; i++) {
		map[i] = [[channelMap objectAtIndex: i] intValue];
	}
	
	err = [_outputUnit caAudioUnit]->SetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, map, dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Output : %@", error);
	}
*/
	if (!channelMap) {
		[self setPrimitiveChannelMap: NULL size: 0];
		return;
	}

	// read the channel map out of the NSArray into a C/C++ array
	UInt32 i, j, mapCount = [self channelMapSize];
	SInt32 map[mapCount];
	for (i = 0; i < mapCount; i++) map[i] = -1;
	
	UInt32 count = MIN(mapCount, [channelMap count]);
	for (i = 0; i < count; i++) {
		map[i] = [[channelMap objectAtIndex: i] intValue];
	}

	/* Sort Channel Map By Patch Channel */
	NSMutableArray* channelMapSortedByPatchChannel = [NSMutableArray array];
	for(i = 0; i < [channelMap count]; i++) { //Devices
		for(j = 0; j < [channelMap count]; j++) { //Channels
			if(i==[[channelMap objectAtIndex:j] intValue]) {
				[channelMapSortedByPatchChannel addObject:[NSNumber numberWithInt:j]];
				continue;
			}
		}
	}

	[self setChannelMapSortedByPatchChannel:channelMapSortedByPatchChannel];
	
	[self setPrimitiveChannelMap: map size: mapCount];
}

- (NSArray *)channelMapSortedByPatchChannel
{
	return _channelMapSortedByPatchChannel;
}


- (UInt32)channelMapSize
{
	// find out how much space the channel map takes
	OSStatus err; UInt32 dataSize; Boolean writable;
	err = [_outputUnit caAudioUnit]->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, &dataSize, &writable);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetPropertyInfo ChannelMap, Input : %@", error);
	}
	
	UInt32 mapCount = dataSize / sizeof(SInt32);
	return mapCount;
}

- (UInt32)getPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size
{
	// read the channel map
	OSStatus err; UInt32 dataSize = size * sizeof(SInt32);
	err = [_outputUnit caAudioUnit]->GetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, map, &dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Input : %@", error);
	}
	return dataSize / sizeof(SInt32);
}

- (void)setPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size
{
	OSStatus err; UInt32 dataSize = size * sizeof(SInt32);
	err = [_outputUnit caAudioUnit]->SetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 0, map, dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Input : %@", error);
	}
}

- (AudioStreamBasicDescription)outputUnitStreamFormat { return [[_outputUnit inputBusAtIndex: 0] streamFormat]; }
- (ZKMORAudioUnit *)outputUnit { return _outputUnit; }

- (OSStatus)lastError { return _lastError; }

#pragma mark _____ Input
- (BOOL)canDeliverInput 
{ 
	UInt32 canDeliverInput = 0;
	UInt32 size = sizeof(canDeliverInput);
	// kAudioUnitScope_Input and 1 come from TN2091
	[_outputUnit caAudioUnit]->GetProperty(kAudioOutputUnitProperty_HasIO, kAudioUnitScope_Input, 1, &canDeliverInput,	&size);
	return canDeliverInput;
}

- (BOOL)isInputEnabled 
{ 
	UInt32 isInputEnabled = 0;
	UInt32 size = sizeof(isInputEnabled);
	// kAudioUnitScope_Input and 1 come from TN2091
	[_outputUnit caAudioUnit]->GetProperty(kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &isInputEnabled, &size);
	return isInputEnabled;
}

- (void)setInputEnabled:(BOOL)isEnabled
{ 
	if (![self canDeliverInput]) return;
	if ([self isInputEnabled] == isEnabled) return;
	
	BOOL wasRunning = [self isRunning];
	if (wasRunning) [self stop];
	
	BOOL wasInitialized = [_outputUnit isInitialized];
	if (wasInitialized) [_outputUnit uninitialize];
	UInt32 isInputEnabled = isEnabled;
	UInt32 size = sizeof(isInputEnabled);
	OSStatus err = [_outputUnit caAudioUnit]->SetProperty(kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &isInputEnabled, size);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Hardware, CFSTR("Could not enable input %i"), err);
		[_outputUnit initialize];
		if (wasRunning) [self start];
		return;
	}

	[[self deviceInput] outputDeviceChanged];
	
	if (wasInitialized) [_outputUnit initialize];
	if (wasRunning) [self start];
}

- (ZKMORDeviceInput *)deviceInput { return _deviceInput; }

- (BOOL)isDefaultOutput { return NO; }


#pragma mark _____ ZKMOROutput Overrides
- (void)setGraph:(ZKMORGraph *)graph
{
	[super setGraph: graph];
	[_graph setGraphSampleRate: [_outputDevice nominalSampleRate]];
		// needs to come after the sample rate change, since that may change the stream format
	[self graphOutputStreamFormatChanged];
}

- (void)start 
{
	[super start];
	[_clock start];
	_lastError = noErr;
	OSStatus err = AudioOutputUnitStart([_outputUnit audioUnit]);
	if (err) {
		ZKMORLogError(kZKMORLogSource_Hardware, CFSTR("Could not start output %i / %4.4s"), err, &err);
		[super stop];
	}
}

- (void)stop 
{
	OSStatus err = AudioOutputUnitStop([_outputUnit audioUnit]);
	if (err) ZKMORLogError(kZKMORLogSource_Hardware, CFSTR("Could not stop output %i / %4.4s"), err, &err);
	[_clock stop];	
	[super stop];
}

- (void)graphOutputStreamFormatChanged
{
	if (_graph && [_graph head]) {
		BOOL wasRunning = [self isRunning];
		if (wasRunning) [self stop];
		[_outputUnit uninitialize];
		[[_outputUnit inputBusAtIndex: 0] 
			setStreamFormat: [[_graph outputBusAtIndex: 0] streamFormat]];
		[_outputUnit initialize];
		if (wasRunning) [self start];
	}
}

@end


static OSStatus ZKMORDeviceInputRenderFunc(	id							SELF,
											AudioUnitRenderActionFlags 	* ioActionFlags,
											const AudioTimeStamp 		* inTimeStamp,
											UInt32						inOutputBusNumber,
											UInt32						inNumberFrames,
											AudioBufferList				* ioData)
{
	//NSLog(@"Device Input Render Func");
	ZKMORDeviceInputStruct* theInput = (ZKMORDeviceInputStruct*) SELF;
	ZKMORAudioUnitStruct* theAU = (ZKMORAudioUnitStruct*)theInput->_outputUnit;
	CAAudioUnitZKM* caAU = theAU->mAudioUnit;
	return caAU->Render(ioActionFlags, inTimeStamp, 1, inNumberFrames, ioData);
}

@implementation ZKMORDeviceInput

#pragma mark _____ ZKMORDeviceInputPrivate
- (id)initWithDeviceOutput:(ZKMORDeviceOutput *)deviceOutput
{
	if (!(self = [super init])) return nil;

	_conduitType = kZKMORConduitType_Source;

	_deviceOutput = deviceOutput;
	_outputUnit = [_deviceOutput outputUnit];
	
	return self;
}

- (void)outputDeviceChanged
{
	if (![_deviceOutput isInputEnabled]) return;
	
	[self uninitialize];
	Float64 sampleRate = [[_deviceOutput outputDevice] nominalSampleRate];
	ZKMORConduitBus* outputBus = [self outputBusAtIndex: 0];
	[outputBus setSampleRate: sampleRate];
	[self initialize];	
}

- (CAAudioUnit *)outputCAAudioUnit { return [[_deviceOutput outputUnit] caAudioUnit]; }

#pragma mark _____ Accessors
- (ZKMORDeviceOutput *)deviceOutput { return _deviceOutput; }
- (unsigned)numberOfChannels { return [[self outputBusAtIndex: 0] numberOfChannels]; }
- (void)setNumberOfChannels:(unsigned)numberOfChannels
{
	BOOL wasRunning = [_deviceOutput isRunning];
	if (wasRunning) [_deviceOutput stop];
	[_outputUnit uninitialize];
	[self uninitialize];
	AudioStreamBasicDescription streamFormat = [[self outputBusAtIndex: 0] streamFormat];
	ZKMORStreamFormatChangeNumberOfChannels(&streamFormat, numberOfChannels);
	[[self outputBusAtIndex: 0] setStreamFormat: streamFormat];
	[self initialize];
	[_outputUnit initialize];
	if (wasRunning) [_deviceOutput start];			
}

- (NSMutableArray *)channelMap 
{
/*
	// find out how much space the channel map takes
	OSStatus err; UInt32 dataSize; Boolean writable;
		// kAudioUnitScope_Output and 1 come from TN2091
	err = [self outputCAAudioUnit]->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, &dataSize, &writable);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetPropertyInfo ChannelMap, Input : %@", error);
	}
	
	if (dataSize < 1) return nil;

	// read the channel map
	UInt32 mapCount = dataSize / sizeof(SInt32);
	SInt32 map[mapCount];
	err = [self outputCAAudioUnit]->GetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, map, &dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Input : %@", error);
	}
	
	// convert the map to a Cocoa thing
	NSMutableArray* channelMap = [NSMutableArray arrayWithCapacity: mapCount];
	unsigned i;
	for (i = 0; i < mapCount; i++) {
		[channelMap addObject: [NSNumber numberWithInt: map[i]]];
	}

	return channelMap;
*/
	UInt32 mapCount = [self channelMapSize];
	SInt32 map[mapCount];
	[self getPrimitiveChannelMap: map size: mapCount];
	
	// convert the map to a Cocoa thing
	NSMutableArray* channelMap = [NSMutableArray arrayWithCapacity: mapCount];
	unsigned i;
	for (i = 0; i < mapCount; i++) {
		[channelMap addObject: [NSNumber numberWithInt: map[i]]];
	}

	return channelMap;
}
- (void)setChannelMap:(NSArray *)channelMap
{
/*
	// TODO -- Verify that the channel map works for the format
	OSStatus err; UInt32 dataSize; Boolean writable; unsigned i;
	if (!channelMap) {
			// kAudioUnitScope_Output and 1 come from TN2091
		err = [self outputCAAudioUnit]->SetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, NULL, 0);
		if (err) {
			NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
			ZKMORThrow(AudioUnitError, @"SetProperty to Null ChannelMap, Input : %@", error);
		}
		
		return;
	}
	
	// find out how much space the channel map takes
	err = [self outputCAAudioUnit]->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, &dataSize, &writable);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetPropertyInfo ChannelMap, Input : %@", error);
	}

	// read the channel map out of the NSArray into a C/C++ array
	UInt32 mapCount = dataSize / sizeof(SInt32);
	SInt32 map[mapCount];
	for (i = 0; i < mapCount; i++) map[i] = -1;
	
	UInt32 count = MIN(mapCount, [channelMap count]);
	for (i = 0; i < count; i++) {
		map[i] = [[channelMap objectAtIndex: i] intValue];
	}
	
	err = [self outputCAAudioUnit]->SetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, map, dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Input : %@", error);
	}
*/
	if (!channelMap) {
		[self setPrimitiveChannelMap: NULL size: 0];
		return;
	}

	// read the channel map out of the NSArray into a C/C++ array
	UInt32 i, mapCount = [self channelMapSize];
	SInt32 map[mapCount];
	for (i = 0; i < mapCount; i++) map[i] = -1;
	
	UInt32 count = MIN(mapCount, [channelMap count]);
	for (i = 0; i < count; i++) {
		map[i] = [[channelMap objectAtIndex: i] intValue];
	}
	
	[self setPrimitiveChannelMap: map size: mapCount];
}


- (UInt32)channelMapSize
{
	// find out how much space the channel map takes
	OSStatus err; UInt32 dataSize; Boolean writable;
		// kAudioUnitScope_Output and 1 come from TN2091
	err = [self outputCAAudioUnit]->GetPropertyInfo(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, &dataSize, &writable);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetPropertyInfo ChannelMap, Input : %@", error);
	}
	
	UInt32 mapCount = dataSize / sizeof(SInt32);
	return mapCount;
}

- (UInt32)getPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size
{
	// read the channel map
	OSStatus err; UInt32 dataSize = size * sizeof(SInt32);
		// kAudioUnitScope_Output and 1 come from TN2091
	err = [self outputCAAudioUnit]->GetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, map, &dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Input : %@", error);
	}
	return dataSize / sizeof(SInt32);
}

- (void)setPrimitiveChannelMap:(SInt32 *)map size:(UInt32)size
{
	OSStatus err; UInt32 dataSize = size * sizeof(SInt32);
		// kAudioUnitScope_Output and 1 come from TN2091
	err = [self outputCAAudioUnit]->SetProperty(kAudioOutputUnitProperty_ChannelMap, kAudioUnitScope_Output, 1, map, dataSize);
	if (err) {
		NSError* error = [NSError errorWithDomain: NSOSStatusErrorDomain code: err userInfo: nil];
		ZKMORThrow(AudioUnitError, @"GetProperty ChannelMap, Input : %@", error);
	}
}

#pragma mark _____ Queries
- (BOOL)isValid { return [_deviceOutput canDeliverInput] && [_deviceOutput isInputEnabled]; }

#pragma mark _____ ZKMORConduit Overrides
- (unsigned)numberOfInputBuses { return 0; }
- (unsigned)numberOfOutputBuses { return 1; }

- (void)setStreamFormatForBus:(ZKMORConduitBus *)bus 
{ 
	if (![_deviceOutput isInputEnabled]) return;
	[_outputUnit uninitialize];
	[[_outputUnit outputBusAtIndex: 1] setStreamFormat: [bus streamFormat]];
	[_outputUnit initialize];	
	[self getStreamFormatForBus: bus];
}

- (void)getStreamFormatForBus:(ZKMORConduitBus *)bus {
	if (![_deviceOutput isInputEnabled]) return;
	ZKMORConduitBusStruct* busStruct = (ZKMORConduitBusStruct *)bus;
	busStruct->_streamFormat = [[_outputUnit outputBusAtIndex: 1] streamFormat];
}

// ignore changes -- the sample rate is always the same as devices, no matter what the graph wants.
- (void)graphSampleRateChanged:(Float64)graphSampleRate { }

- (ZKMORRenderFunction)renderFunction { return ZKMORDeviceInputRenderFunc; }

@end


@implementation ZKMORDefaultOutput

- (BOOL)createOutputUnitAndDevice
{
	Component comp;
	ComponentDescription desc;
	AudioUnit copyDefaultOutput;
	
	desc.componentType = kAudioUnitType_Output;
	desc.componentSubType = kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	desc.componentFlags = 0;
	desc.componentFlagsMask = 0;
	comp = FindNextComponent(NULL, &desc);
	if (comp == NULL) return NO;
	if (OpenAComponent(comp, &copyDefaultOutput)) return NO;
	
	_outputUnit = [[ZKMORAudioUnit alloc] initWithAudioUnit: copyDefaultOutput disposeWhenDone: YES];
	
	UInt32 dataSize = sizeof(AudioDeviceID);
	AudioDeviceID defaultDeviceID;
	[_outputUnit caAudioUnit]->GetProperty(kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &defaultDeviceID, &dataSize);
	_outputDevice = [[ZKMORAudioHardwareSystem sharedAudioHardwareSystem] audioDeviceForDeviceID: defaultDeviceID];
	[_outputDevice retain];
	return YES;
}

- (BOOL)setOutputDevice:(ZKMORAudioDevice *)outputDevice error:(NSError **)error
{
	// can't change the device on the default output
	ZKMORLogError(kZKMORLogSource_Hardware, CFSTR("Can not set output device on default output"));
	if (error != NULL)
		*error = [NSError errorWithDomain: NSOSStatusErrorDomain code: paramErr userInfo: nil];
	return NO;
}

@end
