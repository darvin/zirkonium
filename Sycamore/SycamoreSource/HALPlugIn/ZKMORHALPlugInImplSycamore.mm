/*
 *  ZKMORHALPlugInImplSycamore.cpp
 *  CERN
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "ZKMORHALPlugInImplSycamore.h"
#include "CAAudioHardwareSystem.h"
#include "AUOutputBL.h"

#pragma mark _____ CTOR / DTOR
ZKMORHALPlugInImplSycamore::ZKMORHALPlugInImplSycamore(AudioHardwarePlugInRef plugIn) :
	ZKMORHALPlugInImpl(plugIn),
	mDeviceOutput(nil), mGraph(nil), mMixerMatrix(nil), mConduitShim(nil),
	mDeviceInput(nil), mInputRenderFunction(NULL) { }

ZKMORHALPlugInImplSycamore::~ZKMORHALPlugInImplSycamore()
{
	if (mDeviceOutput) [mDeviceOutput release];
	if (mInputBL) delete mInputBL;
}

#pragma mark _____ Actions
void		ZKMORHALPlugInImplSycamore::InitializeDeviceOutput() 
{
	if (!mWrappedDeviceUID) return;
	if (!mWrappedDevice) return;
	if (!IsAlive()) return;

	ZKMORAudioHardwareSystem* ahs = [ZKMORAudioHardwareSystem sharedAudioHardwareSystem];
	mDeviceOutput = [[ZKMORDeviceOutput alloc] init];
	UInt32 startTimestampsAtZero = 0;
	UInt32 dataSize = sizeof(UInt32);
	AudioUnitSetProperty([[mDeviceOutput outputUnit] audioUnit], kAudioOutputUnitProperty_StartTimestampsAtZero, kAudioUnitScope_Global, 0, &startTimestampsAtZero, dataSize);
	ZKMORAudioDevice* device = [ahs audioDeviceForDeviceID: mWrappedDevice];
	NSError* error = nil;
	mGraph = [[ZKMORGraph alloc] init];
	mMixerMatrix = [[ZKMORMixerMatrix alloc] init];
	mConduitShim = [[ZKMORConduitShim alloc] initWithImpl: this];
	
	//  DEBUG
	NSLog(@"InitializeDeviceOutput");
	PatchOutputGraph();
	
	[mDeviceOutput setGraph: mGraph];
	[mMixerMatrix setToCanonicalLevels];

		// pass ownership of everything to the device output
	[mGraph release];
	[mMixerMatrix release];
	[mConduitShim release];

	[mDeviceOutput setOutputDevice: device error: &error];
	if (error) { 
		ZKMCNDebugPrintf("setOutputDevice failed\n"); 
	}
	
	mSampleRate = [mGraph graphSampleRate];
	if (mInputBL) { delete mInputBL; mDeviceInput = nil; mInputRenderFunction = NULL; }
	if ([mDeviceOutput isInputEnabled]) {
		mDeviceInput = [mDeviceOutput deviceInput];
		CAStreamBasicDescription streamFormat([[mDeviceInput outputBusAtIndex: 0] streamFormat]);
		streamFormat.ChangeNumberChannels(mNumberOfInputChannels, false);
		[mDeviceInput uninitialize];
		[[mDeviceInput outputBusAtIndex: 0] setStreamFormat: streamFormat];
		[mDeviceInput initialize];
		
		UInt32 numFrames = [mGraph maxFramesPerSlice];
		mInputBL = new AUOutputBL(streamFormat, numFrames);
		mInputBL->Allocate(numFrames);
		mInputRenderFunction = [mDeviceInput renderFunction];
	} else {
		CAStreamBasicDescription streamFormat([[[mDeviceOutput outputUnit] inputBusAtIndex: 0] streamFormat]);
		streamFormat.ChangeNumberChannels(mNumberOfInputChannels, false);
		UInt32 numFrames = [mGraph maxFramesPerSlice];
		mInputBL = new AUOutputBL(streamFormat, numFrames);
		mInputBL->Allocate(numFrames);		
	}

	
	AudioHardwareDevicePropertyChanged(mPlugIn, mDeviceID, 0, false, kAudioDevicePropertyDeviceHasChanged);
}

void		ZKMORHALPlugInImplSycamore::StartWrappedDevice()
{
	// the running state changed, take action
	[mDeviceOutput start];
}

void		ZKMORHALPlugInImplSycamore::StopWrappedDevice()
{
	// the running state changed, take action
	[mDeviceOutput stop];
}

void	ZKMORHALPlugInImplSycamore::ReadInputFromWrappedDevice(const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames)
{
	AudioUnitRenderActionFlags inputRenderFlags = 0;
	mInputBL->Prepare(inNumberFrames);
		
		// grab input from the device
	if (mDeviceInput) {
		// if mDeviceInput is defined, so is mInputRenderFunction
		mInputRenderFunction(mDeviceInput, &inputRenderFlags, inTimeStamp, 0, inNumberFrames, mInputBL->ABL());
	} else {
		ZKMORMakeBufferListSilent(mInputBL->ABL(), &inputRenderFlags);
	}
}

void		ZKMORHALPlugInImplSycamore::SetNumberOfChannels(unsigned numberOfInputs, unsigned numberOfOutputs)
{
	bool haveGraph = mGraph != NULL;
	if (haveGraph) [mGraph beginPatching];
	ZKMORHALPlugInImpl::SetNumberOfChannels(numberOfInputs, numberOfOutputs);
	if (haveGraph) {
		[mMixerMatrix uninitialize];
		[mConduitShim uninitialize];
		[mDeviceInput uninitialize];
		PatchOutputGraph();
		[mGraph endPatching];
		[mMixerMatrix setToCanonicalLevels];
	}
}


void		ZKMORHALPlugInImplSycamore::PatchOutputGraph()
{	
	[mGraph beginPatching];
		[mGraph setHead: mMixerMatrix];
		[[mConduitShim outputBusAtIndex: 0] setNumberOfChannels: mNumberOfOutputChannels];
		[[mMixerMatrix inputBusAtIndex: 0] setNumberOfChannels: mNumberOfOutputChannels];
		[mGraph patchBus: [mConduitShim outputBusAtIndex: 0] into: [mMixerMatrix inputBusAtIndex: 0]];
		[mGraph initialize];
	[mGraph endPatching];
}

#pragma mark _____ ZKMORConduitShim
OSStatus ZKMORConduitShimCallback(	id							SELF,
									AudioUnitRenderActionFlags 	* ioActionFlags,
									const AudioTimeStamp 		* inTimeStamp,
									UInt32						inOutputBusNumber,
									UInt32						inNumberFrames,
									AudioBufferList				* ioData)
{
	return ((ZKMORConduitShim*) SELF)->mPlugInImpl->RenderClients(ioActionFlags, inTimeStamp, inNumberFrames, ioData);
}


@implementation ZKMORConduitShim

- (id)initWithImpl:(ZKMORHALPlugInImplSycamore *)plugInImpl
{
	if (!(self = [super init])) return nil;
	mPlugInImpl = plugInImpl;
	_conduitType = kZKMORConduitType_Source;
	
	return self;
}

- (unsigned)numberOfInputBuses { return 0; }
- (BOOL)isNumberOfInputBusesSettable { return NO; }
- (unsigned)numberOfOutputBuses { return 1; }
- (BOOL)isNumberOfOutputBusesSettable { return NO; }

- (ZKMORRenderFunction)renderFunction { return ZKMORConduitShimCallback; }

@end
