//
//  ZKMRNHP_Device.mm
//  Zirkonium
//
//  Created by C. Ramakrishnan on 03.04.08.
//  Copyright 2008 Illposed Software. All rights reserved.
//

#import "ZKMRNHP_Device.h"
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

ZKMRNHP_Device::ZKMRNHP_Device(AudioDeviceID inAudioDeviceID, ZKMORHP_PlugIn* inPlugIn) 
	: ZKMORHP_DeviceSycamore(inAudioDeviceID, inPlugIn, DEVICE_NUM_CHANNELS, DEVICE_NUM_CHANNELS, CFSTR("Zirkonium"), CFSTR("ZKM"), CFSTR("de_zkm_ZirkoniumDeviceUID"), CFSTR("de_zkm_ZirkoniumModelUID"), CFSTR("de.zkm.Zirkonium")),
	mOutputChannelMapSize(0),
	mOutputChannelMap(NULL),
	mSpeakerLayoutSimulator(NULL),
	mLoudspeakerMode(0),
	mSimulationMode(kZKMNRSpeakerLayoutSimulationMode_Headphones),
	mSpeakerLayout(NULL)
{
	mClient.SetDelegate(this);

	ZKMORLoggerSetLogLevel(kZKMORLogLevel_Debug);
	ZKMORLoggerSetIsLogging(YES);
	ZKMORLogPrinterStart();
}

ZKMRNHP_Device::~ZKMRNHP_Device() 
{ 
	if (mOutputChannelMap) free(mOutputChannelMap), mOutputChannelMap = NULL;
	if (mSpeakerLayoutSimulator) [mSpeakerLayoutSimulator release];
	if (mSpeakerLayout) [mSpeakerLayout release];
}

void	ZKMRNHP_Device::Initialize()
{
	ZKMORHP_DeviceSycamore::Initialize();
	AudioHardwareAddRunLoopSource(mClient.GetRunLoopSource());
	mClient.Connect();
}

void		ZKMRNHP_Device::InitializeDeviceOutput() 
{
	mSpeakerLayoutSimulator = [[ZKMNRSpeakerLayoutSimulator alloc] init];
	ZKMORHP_DeviceSycamore::InitializeDeviceOutput();
}

void		ZKMRNHP_Device::PatchOutputGraph() 
{	
	// inline the referenced method
//	ZKMORHP_DeviceSycamore::PatchOutputGraph();
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
				
		if (kZKMRNSystemLoudspeakerMode_Real == mLoudspeakerMode || !mSpeakerLayout) {
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

/*	
//	[mGraph setDebugLevel: kZKMORDebugLevel_All];
	//  DEBUG
	NSLog(@"PatchOutputGraph");
	[mGraph logDebug];
	[mMixerMatrix logDebug];
	[[mSpeakerLayoutSimulator mixer3D] logDebug];
	NSLog(@"Speaker layout %@", [mSpeakerLayout speakerLayoutName]);
*/
}

#pragma mark _____ ClientPortDelegate
void		ZKMRNHP_Device::ReceiveSetMatrix(CFIndex lengthInBytes, Float32* coeffs)
{
	if (!IsAlive()) return;
	if (!IsDeviceOutputInitialized()) return;
	if (![mMixerMatrix isInitialized]) { /* NSLog(@"ZKMRNHP_Device: Mixer not initialized"); */ return; }
	unsigned mixerSize[2];
	[mMixerMatrix getMixerLevelsDimensionsInput: &mixerSize[0] output: &mixerSize[1]];
	unsigned sentLength = lengthInBytes / sizeof(Float32);
	unsigned myLength = (mixerSize[0] * mixerSize[1]);
	if (sentLength != myLength) {
		NSLog(@"ZKMRNHP_Device: Error: Received matrix of size %u, have space for %u : %u x %u", sentLength, myLength, mixerSize[0], mixerSize[1]);
	} else {
		[mMixerMatrix setMixerLevels: coeffs size: sentLength];
	}
}

void		ZKMRNHP_Device::ReceiveOutputChannelMap(UInt32 mapSize, SInt32* map)
{
	if (!IsAlive()) return;

	mOutputChannelMapSize = mapSize;
	if (mOutputChannelMap) free(mOutputChannelMap);
	mOutputChannelMap = (SInt32 *) malloc(sizeof(SInt32) * mapSize);
	memcpy(mOutputChannelMap, map, sizeof(SInt32) * mapSize);
	
	if (!IsDeviceOutputInitialized()) return;

	[mDeviceOutput setPrimitiveChannelMap: mOutputChannelMap size: mOutputChannelMapSize];
}

void		ZKMRNHP_Device::ReceiveSpeakerMode(UInt8 numberOfInputs, UInt8 numberOfOutputs, UInt8 speakerMode, UInt8 simulationMode, CFDataRef speakerLayout)
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

void		ZKMRNHP_Device::ReceiveNumberOfChannels(UInt32 numberOfChannels)
{
	if (!IsAlive()) return;
	mNumberOfInputChannels = numberOfChannels;
	mNumberOfOutputChannels = numberOfChannels;	
}

void ZKMRNHP_Device::ReceiveLogLevel(bool debugIsOn, UInt32 debugLevel)
{
	ZKMORLoggerSetLogLevel(debugLevel);
	ZKMORLoggerSetIsLogging(debugIsOn);
}

#pragma mark _____ Queries
bool		ZKMRNHP_Device::IsAlive() 
{ 
	if (!ZKMORHP_DeviceSycamore::IsAlive()) return false;

	if (!mClient.IsConnected()) mClient.Connect();
	return mClient.IsConnected();
}
