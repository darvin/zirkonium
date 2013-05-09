/*
 *  CAAudioUnitZKM.h
 *  Sycamore
 *
 *  Created by Chandrasekhar Ramakrishnan on 24.08.06.
 *  Copyright 2006 C. Ramakrishnan/ZKM. All rights reserved.
 *
 *  Extensions to CAAudioUnit
 *
 */

#ifndef __CAAudioUnitZKM_h__
#define __CAAudioUnitZKM_h__

#include "CAAudioUnit.h"
#include <AudioToolbox/AudioToolbox.h>

class CAAudioUnitZKM : public CAAudioUnit {

public:
//  CTORs
	CAAudioUnitZKM();

	CAAudioUnitZKM(const AudioUnit& inUnit);
	
	~CAAudioUnitZKM();
	
//  Accessors
//  these methods throw exceptions when things don't work
	// Stream Format
	void GetInputStreamFormat(AudioUnitElement inEl, AudioStreamBasicDescription &outFormat);
	void GetOutputStreamFormat(AudioUnitElement inEl, AudioStreamBasicDescription &outFormat);
	
	void SetInputStreamFormat(AudioUnitElement inEl, const AudioStreamBasicDescription &inFormat);
	void SetOutputStreamFormat(AudioUnitElement inEl, const AudioStreamBasicDescription &inFormat);
	
	// Max Frames
	UInt32 GetMaximumFramesPerSlice();
	void   SetMaximumFramesPerSlice(UInt32 maxFrames);
	
	// Presets
	void GetFactoryPresets(CFArrayRef& presets);
	void SetCurrentFactoryPreset(SInt32 factoryPresetNumber);	

	// Parameters
	UInt32 GetNumParameters(AudioUnitScope inScope, AudioUnitElement bus);
	void   GetParameterIDs(AudioUnitScope inScope, AudioUnitElement bus, AudioUnitParameterID* paramIDArray, UInt32* paramIDArrayByteSize);
	void   GetParameterInfo(AudioUnitScope inScope, AudioUnitParameterID paramID, AudioUnitParameterInfo* paramInfo);

	UInt32 GetGlobalNumParameters();
	void   GetGlobalParameterIDs(AudioUnitParameterID* paramIDArray, UInt32* paramIDArrayByteSize);
	void   GetGlobalParameterInfo(AudioUnitParameterID paramID, AudioUnitParameterInfo* paramInfo);

	// Buses
	UInt32 GetInputBusCount();
	UInt32 GetOutputBusCount();
	
	// Render Callbacks -- the callback argument is a pointer because it can be NULL
	void GetRenderCallback(AudioUnitElement bus, AURenderCallbackStruct* callback);
	void SetRenderCallback(AudioUnitElement bus, AURenderCallbackStruct* callback);

	// Channel Configurations
	UInt32 GetNumSupportedNumChannels();
	void   GetSupportedNumChannels(AUChannelInfo* channelInfos, UInt32* channelInfosByteSize);
	
	// Property Listening
	ComponentResult			AddPropertyListener (AudioUnitPropertyID inID, AudioUnitPropertyListenerProc inProc, void* inProcRefCon)
							{
								return AudioUnitAddPropertyListener (AU(), inID, inProc, inProcRefCon);
							}

	ComponentResult			RemovePropertyListener (AudioUnitPropertyID inID, AudioUnitPropertyListenerProc inProc)
							{
								return AudioUnitRemovePropertyListener (AU(), inID, inProc);
							}
							
	// Parameters
	OSStatus				SetParameterViaListener(	AudioUnitParameterID	inID, 
														AudioUnitScope			scope, 
														AudioUnitElement		element,
														Float32					value, 
														UInt32					bufferOffsetFrames=0);
														
	OSStatus				ScheduleParameterViaListener(	const AudioUnitParameterEvent *  inParameterEvent,
															UInt32                           inNumParamEvents);

protected:
// IVARs
	AUEventListenerRef	mEventListener;
	
};

#endif // __CAAudioUnitZKM_h__
