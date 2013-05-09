/*
 *  CAAudioUnitZKM.cpp
 *  Sycamore
 *
 *  Created by Chandrasekhar Ramakrishnan on 24.08.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "CAAudioUnitZKM.h"
#include "CAXException.h"

void CAAudioUnitZKMEventListener(		void*					refCon,
										void*					changer,
										const AudioUnitEvent*	event,
										UInt64					eventHostTime,
										Float32					parameterValue)
{
	// Do nothing
}	

CAAudioUnitZKM::CAAudioUnitZKM() : CAAudioUnit() 
{
	XThrowIfError(
		AUEventListenerCreate(	CAAudioUnitZKMEventListener,		// listener func
								this,								// ref con
								CFRunLoopGetCurrent(),				// run loop
								kCFRunLoopDefaultMode,				// run loop mode
								(Float32) (1.f),					// in seconds
								(Float32) (1.f),					// in seconds
								&mEventListener),
		"create CAAudioUnitZKM event listener"
	);									
}

CAAudioUnitZKM::CAAudioUnitZKM(const AudioUnit& inUnit) : CAAudioUnit(inUnit) 
{ 
	XThrowIfError(
		AUEventListenerCreate(	CAAudioUnitZKMEventListener,		// listener func
								this,								// ref con
								CFRunLoopGetCurrent(),				// run loop
								kCFRunLoopDefaultMode,				// run loop mode
								(Float32) (1.f),					// in seconds
								(Float32) (1.f),					// in seconds
								&mEventListener),
		"create CAAudioUnitZKM event listener"
	);
}

CAAudioUnitZKM::~CAAudioUnitZKM() 
{ 
	AUListenerDispose(mEventListener);
}

void	CAAudioUnitZKM::GetInputStreamFormat(AudioUnitElement inEl, AudioStreamBasicDescription &outFormat)
{
	XThrowIfError(
		GetFormat(kAudioUnitScope_Input, inEl, outFormat), 
		"get input stream format"
	);			
}

void	CAAudioUnitZKM::GetOutputStreamFormat(AudioUnitElement inEl, AudioStreamBasicDescription &outFormat)
{
	XThrowIfError(
		GetFormat(kAudioUnitScope_Output, inEl, outFormat), 
		"get output stream format"
	);	
}

void	CAAudioUnitZKM::SetInputStreamFormat(AudioUnitElement inEl, const AudioStreamBasicDescription &inFormat)
{
	XThrowIfError(
		SetFormat(kAudioUnitScope_Input, inEl, inFormat), 
		"set input stream format"
	);
}

void	CAAudioUnitZKM::SetOutputStreamFormat(AudioUnitElement inEl, const AudioStreamBasicDescription &inFormat)
{
	XThrowIfError(
		SetFormat(kAudioUnitScope_Output, inEl, inFormat), 
		"set output stream format"
	);
}

UInt32	CAAudioUnitZKM::GetMaximumFramesPerSlice()
{
	UInt32 dataSize = sizeof(UInt32);
	UInt32 maxFrames;
	XThrowIfError(
		GetProperty(kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, &dataSize), 
		"get max frames per slice"
	);
	return maxFrames;
}

void	CAAudioUnitZKM::SetMaximumFramesPerSlice(UInt32 maxFrames)
{
	UInt32 dataSize = sizeof(UInt32);
	XThrowIfError(
		SetProperty(kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFrames, dataSize), 
		"set max frames per slice"
	);
}

void	CAAudioUnitZKM::GetFactoryPresets(CFArrayRef& presets)
{
	UInt32 dataSize = sizeof(CFArrayRef);
	XThrowIfError(
		GetProperty(kAudioUnitProperty_FactoryPresets, kAudioUnitScope_Global, 0, &presets, &dataSize), 
		"get max factory presets"
	);
}

void	CAAudioUnitZKM::SetCurrentFactoryPreset(SInt32 factoryPresetNumber)
{
	AUPreset preset;
	preset.presetName = NULL;
	preset.presetNumber = factoryPresetNumber;
	SetPresentPreset(preset);
}

UInt32	CAAudioUnitZKM::GetNumParameters(AudioUnitScope inScope, AudioUnitElement bus)
{
	Boolean writeable;
	UInt32 paramIDArrayByteSize;
	XThrowIfError(
		GetPropertyInfo(kAudioUnitProperty_ParameterList, inScope, 0, &paramIDArrayByteSize, &writeable), 
		"get parameter ids size"
	);
	return paramIDArrayByteSize / sizeof(AudioUnitParameterID);
}

void	CAAudioUnitZKM::GetParameterIDs(	AudioUnitScope			inScope,
										AudioUnitElement		bus,
										AudioUnitParameterID*	paramIDArray, 
										UInt32*					paramIDArrayByteSize)
{
	XThrowIfError(
		GetProperty(kAudioUnitProperty_ParameterList, inScope, bus, paramIDArray, paramIDArrayByteSize), 
		"get parameter ids"
	);	
}

void	CAAudioUnitZKM::GetParameterInfo(AudioUnitScope inScope, AudioUnitParameterID paramID, AudioUnitParameterInfo* paramInfo)
{
	UInt32 dataSize = sizeof(AudioUnitParameterInfo);
	XThrowIfError(
		GetProperty(kAudioUnitProperty_ParameterInfo, inScope, paramID, paramInfo, &dataSize), 
		"get parameter id info"
	);	
}

UInt32	CAAudioUnitZKM::GetGlobalNumParameters()
{
	return GetNumParameters(kAudioUnitScope_Global, 0);
}

void	CAAudioUnitZKM::GetGlobalParameterIDs(AudioUnitParameterID* paramIDArray, UInt32* paramIDArrayByteSize)
{
	GetParameterIDs(kAudioUnitScope_Global, 0, paramIDArray, paramIDArrayByteSize);
}

void	CAAudioUnitZKM::GetGlobalParameterInfo(AudioUnitParameterID paramID, AudioUnitParameterInfo* paramInfo)
{
	GetParameterInfo(kAudioUnitScope_Global, paramID, paramInfo);
}

UInt32	CAAudioUnitZKM::GetInputBusCount()
{
	UInt32 dataSize = sizeof(UInt32);
	UInt32 busCount;
	XThrowIfError(
		GetProperty(kAudioUnitProperty_BusCount, kAudioUnitScope_Input, 0, &busCount, &dataSize), 
		"get input bus count"
	);
	return busCount;
}

UInt32	CAAudioUnitZKM::GetOutputBusCount()
{
	UInt32 dataSize = sizeof(UInt32);
	UInt32 busCount;
	XThrowIfError(
		GetProperty(kAudioUnitProperty_BusCount, kAudioUnitScope_Output, 0, &busCount, &dataSize), 
		"get output bus count"
	);
	return busCount;
}

UInt32	CAAudioUnitZKM::GetNumSupportedNumChannels()
{
	Boolean writable = 0;
	UInt32	dataSize = 0;
	XThrowIfError(
		GetPropertyInfo(kAudioUnitProperty_SupportedNumChannels, kAudioUnitScope_Global, 0, &dataSize, &writable), 
		"get num supported num channels"
	);
	return dataSize / sizeof(AUChannelInfo);
}

void	CAAudioUnitZKM::GetSupportedNumChannels(AUChannelInfo* channelInfos, UInt32* channelInfosByteSize)
{
	XThrowIfError(
		GetProperty(kAudioUnitProperty_SupportedNumChannels, kAudioUnitScope_Global, 0, channelInfos, channelInfosByteSize), 
		"get supported num channels"
	);
}

void	CAAudioUnitZKM::GetRenderCallback(AudioUnitElement bus, AURenderCallbackStruct* callback)
{
	UInt32 dataSize = sizeof(AURenderCallbackStruct);
	XThrowIfError(
		GetProperty(kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, bus, callback, &dataSize), 
		"get render callback"
	);
}

void	CAAudioUnitZKM::SetRenderCallback(AudioUnitElement bus, AURenderCallbackStruct* callback)
{

	UInt32 dataSize = sizeof(AURenderCallbackStruct);
	XThrowIfError(
		SetProperty(kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, bus, callback, dataSize), 
		"set render callback"
	);
}

OSStatus	CAAudioUnitZKM::SetParameterViaListener(	AudioUnitParameterID	inID, 
														AudioUnitScope			scope, 
														AudioUnitElement		element,
														Float32					value, 
														UInt32					bufferOffsetFrames)
{
	AudioUnitParameter parameter = { AU(), inID, scope, element };
	return AUParameterSet(mEventListener, this, &parameter, value, bufferOffsetFrames);
}

OSStatus	CAAudioUnitZKM::ScheduleParameterViaListener(	const AudioUnitParameterEvent *  inParameterEvent,
															UInt32                           inNumParamEvents)
{
	// TODO -- this is not really complete, but should work for the moment
	OSStatus err = AudioUnitScheduleParameters(AU(), inParameterEvent, inNumParamEvents);
	AudioUnitEvent event = {	kAudioUnitEvent_ParameterValueChange, 
								AU(), 
								inParameterEvent->parameter, 
								inParameterEvent->scope, 
								inParameterEvent->element };
	AUEventListenerNotify(mEventListener, this, &event);
	return err;
}
