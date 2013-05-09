//
//  ZKMRNHALPlugInImpl.mm
//  CERN
//
//  Created by Chandrasekhar Ramakrishnan on 28.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#import "ZKMRNHALPlugInImpl.h"
#include "ZKMRNHALPlugIn.h"
#include "CAAudioHardwareSystem.h"
#include "AUOutputBL.h"
#import "ZKMRNDeviceConstants.h"

enum {
	kZKMRNSystemLoudspeakerMode_Real = 0,
	kZKMRNSystemLoudspeakerMode_Virtual = 1
};
 
 static void LogMixerLevels(Float32* mixerLevels, unsigned inputs, unsigned outputs)
{
	unsigned i, j;
	for (i = 0; i < (inputs + 1); ++i) {
		if (i < inputs) {
			printf("\t%.3f   ", mixerLevels[(i + 1) * (outputs + 1) - 1]);
			for (j = 0; j < outputs; ++j)
				printf("(%.3f) ", mixerLevels[(i * (outputs + 1)) + j]);
			printf("\n");
		} else {
			printf("\t%.3f   ", mixerLevels[(inputs + 1) * (outputs + 1) - 1]);
			for (j = 0; j < outputs; ++j)
				printf(" %.3f  ", mixerLevels[(i * (outputs + 1)) + j]);
			printf("\n");
		}
	}
	printf("\n");
}

 static void LogMixerLevels2(Float32* mixerLevels, unsigned inputs, unsigned outputs)
{
	unsigned i, j;
	for (i = 0; i < inputs; ++i) {
		for (j = 0; j < outputs; ++j)
			printf("(%.3f) ", mixerLevels[(i * (outputs + 1)) + j]);
		printf("\n");
	}
	printf("\n");
}

#pragma mark _____ CTOR / DTOR
ZKMRNHALPlugInImpl::ZKMRNHALPlugInImpl(AudioHardwarePlugInRef plugIn) :
	ZKMORHALPlugInImplSycamore(plugIn),
	mOutputChannelMapSize(0),
	mOutputChannelMap(NULL),
	mLoudspeakerMode(0)
{
	mClient.SetDelegate(this);
	mDeviceName = CFSTR("Zirkonium");
	mDeviceManu = CFSTR("ZKM");
	mDeviceUID = CFSTR("de_zkm_ZirkoniumDeviceUID");
	mModelUID = CFSTR("de_zkm_ZirkoniumModelUID");	
	mConfigApplication = CFSTR("com.apple.audio.AudioMIDISetup");
	mDefaultsDomain = CFSTR("de.zkm.Zirkonium");
	
	if (IsRunningInZirkonium()) return;
	
	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLogPrinterStart();
	
	mNumberOfInputChannels = DEVICE_NUM_CHANNELS;
	mNumberOfOutputChannels = DEVICE_NUM_CHANNELS;
//	mSpeakerLayoutSimulator = [[ZKMNRSpeakerLayoutSimulator alloc] init];
}

ZKMRNHALPlugInImpl::~ZKMRNHALPlugInImpl()
{
	if (mOutputChannelMap) free(mOutputChannelMap), mOutputChannelMap = NULL;
	if (mSpeakerLayoutSimulator) [mSpeakerLayoutSimulator release];
	if (mSpeakerLayout) [mSpeakerLayout release];	
}

#pragma mark _____ HAL API Overrides
OSStatus	ZKMRNHALPlugInImpl::Initialize()
{
	OSStatus err = ZKMORHALPlugInImplSycamore::Initialize();
	AudioHardwareAddRunLoopSource(mClient.GetRunLoopSource());
	mClient.Connect();
	return err;
}

#pragma mark _____ Actions
void		ZKMRNHALPlugInImpl::InitializeDeviceOutput() 
{
	mSpeakerLayoutSimulator = [[ZKMNRSpeakerLayoutSimulator alloc] init];
	ZKMORHALPlugInImplSycamore::InitializeDeviceOutput();
}

void		ZKMRNHALPlugInImpl::PatchOutputGraph() 
{	
	// inline the referenced method
//	ZKMORHALPlugInImplSycamore::PatchOutputGraph();
	[mGraph beginPatching];
	
		if (mSpeakerLayout) [mSpeakerLayoutSimulator setSpeakerLayout: mSpeakerLayout];
		[mSpeakerLayoutSimulator setSimulationMode: mSimulationMode];
	
		[mMixerMatrix uninitialize];
		[mConduitShim uninitialize];
		[mDeviceInput uninitialize];
		
		[mDeviceOutput setPrimitiveChannelMap: mOutputChannelMap size: mOutputChannelMapSize];
		[[mMixerMatrix outputBusAtIndex: 0] setNumberOfChannels: mMixerNumberOfOutputs];
	
		[[mConduitShim outputBusAtIndex: 0] setNumberOfChannels: mNumberOfOutputChannels];
		[[mMixerMatrix inputBusAtIndex: 0] setNumberOfChannels: mNumberOfOutputChannels];
		[mGraph patchBus: [mConduitShim outputBusAtIndex: 0] into: [mMixerMatrix inputBusAtIndex: 0]];
				
		if (kZKMRNSystemLoudspeakerMode_Real == mLoudspeakerMode) {
			[mMixerMatrix setNumberOfOutputBuses: 1];
			[mGraph setHead: mMixerMatrix];
		} else {
			ZKMORMixer3D* mixer3D = [mSpeakerLayoutSimulator mixer3D];
			[mixer3D uninitialize];
			unsigned i, numberOfSpeakers = mMixerNumberOfOutputs;
			[mMixerMatrix setNumberOfOutputBuses: numberOfSpeakers];
			for (i = 0; i < numberOfSpeakers; i++) {
				ZKMOROutputBus* outputBus = [mMixerMatrix outputBusAtIndex: i];
				[outputBus setNumberOfChannels: 1];
				[mGraph patchBus: outputBus into: [mixer3D inputBusAtIndex: i]];
			}
			[mGraph setHead: mixer3D];			
		}	
		[mGraph initialize];
	[mGraph endPatching];
	
//	[mGraph setDebugLevel: kZKMORDebugLevel_All];
}

#pragma mark _____ ClientPortDelegate
void		ZKMRNHALPlugInImpl::ReceiveSetMatrix(CFIndex lengthInBytes, Float32* coeffs)
{
	if (!IsAlive()) return;
	if (!IsDeviceOutputInitialized()) return;
	if (![mMixerMatrix isInitialized]) { NSLog(@"Mixer not initialized"); return; }
	unsigned mixerSize[2];
	[mMixerMatrix getMixerLevelsDimensionsInput: &mixerSize[0] output: &mixerSize[1]];
	unsigned sentLength = lengthInBytes / sizeof(Float32);
	unsigned myLength = (mixerSize[0] * mixerSize[1]);
	if (sentLength != myLength) {
		NSLog(@"Error: Received matrix of size %u, have space for %u", sentLength, myLength);
	} else 
		[mMixerMatrix setMixerLevels: coeffs size: sentLength];
}

void		ZKMRNHALPlugInImpl::ReceiveOutputChannelMap(UInt32 mapSize, SInt32* map)
{
	if (!IsAlive()) return;

	mOutputChannelMapSize = mapSize;
	if (mOutputChannelMap) free(mOutputChannelMap);
	mOutputChannelMap = (SInt32 *) malloc(sizeof(SInt32) * mapSize);
	memcpy(mOutputChannelMap, map, sizeof(SInt32) * mapSize);
	
	if (!IsDeviceOutputInitialized()) return;

	[mDeviceOutput setPrimitiveChannelMap: mOutputChannelMap size: mOutputChannelMapSize];
}

void		ZKMRNHALPlugInImpl::ReceiveSpeakerMode(UInt8 numberOfInputs, UInt8 numberOfOutputs, UInt8 speakerMode, UInt8 simulationMode, CFDataRef speakerLayout)
{
	if (!IsAlive()) return;

	mMixerNumberOfOutputs = numberOfOutputs;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSString* errorString;
	NSDictionary* speakerLayoutDict = 
		[NSPropertyListSerialization 
			propertyListFromData: (NSData *) speakerLayout 
			mutabilityOption: NSPropertyListImmutable 
			format: NULL 
			errorDescription: &errorString];
	if (!speakerLayoutDict) {
		ZKMORLogError(kZKMORLogSource_GUI, CFSTR("Could not deserialize speaker layout %@"), errorString);
		[errorString release];
		return;
	}
	
	ZKMNRSpeakerLayout* layout = [[ZKMNRSpeakerLayout alloc] init];
	[layout setFromDictionaryRepresentation: speakerLayoutDict];
	if (mSpeakerLayout) [mSpeakerLayout release], mSpeakerLayout = nil;
	mSpeakerLayout = layout;
	
	mSimulationMode = (ZKMNRSimulationMode) simulationMode;
	mLoudspeakerMode = speakerMode;
	
	bool haveGraph = mGraph != NULL;
	if (haveGraph) {
		PatchOutputGraph();
		[mMixerMatrix setToCanonicalLevels];
	}
	[pool release];
}

void		ZKMRNHALPlugInImpl::ReceiveNumberOfChannels(UInt32 numberOfChannels)
{
	if (!IsAlive()) return;
	mNumberOfInputChannels = numberOfChannels;
	mNumberOfOutputChannels = numberOfChannels;	
}

void ZKMRNHALPlugInImpl::ReceiveLogLevel(bool debugIsOn, UInt32 debugLevel)
{
	ZKMORLoggerSetLogLevel(debugLevel);
	ZKMORLoggerSetIsLogging(debugIsOn);
}

#pragma mark _____ Queries
bool		ZKMRNHALPlugInImpl::IsAlive() 
{ 
	if (!ZKMORHALPlugInImplSycamore::IsAlive()) return false;
	if (IsRunningInZirkonium()) return false;

	if (!mClient.IsConnected()) mClient.Connect();
	return mClient.IsConnected();
}
