//
//  ZKMRNHP_Device.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 03.04.08.
//  Copyright 2008 Illposed Software. All rights reserved.
//

#ifndef __ZKMRNHP_Device_H__
#define __ZKMRNHP_Device_H__

#include "ZKMORHP_DeviceSycamore.h"
#include "ZKMRNHALPlugInProtocol.h"

/// 
///  ZKMRNHP_Device
///
///  The Zirkonium HAL Plug-In. Note, the plug-in is not instantiated if we are running inside of Zirkonium.
///
class ZKMRNHP_Device : public ZKMORHP_DeviceSycamore, public ZirkoniumHALClientPort::ClientPortDelegate {

public:	
	//  CTOR / DTOR
	ZKMRNHP_Device(AudioDeviceID inAudioDeviceID, ZKMORHP_PlugIn* inPlugIn);
	virtual ~ZKMRNHP_Device();

protected:
	// HAL API Overrides
	void		Initialize();
	
		// Subclass Overrides
	void		InitializeDeviceOutput();
	void		PatchOutputGraph();
		// ClientPortDelegate
	void		ReceiveSetMatrix(CFIndex lengthInBytes, Float32* coeffs);
	void		ReceiveOutputChannelMap(UInt32 mapSize, SInt32* map);
	void		ReceiveSpeakerMode(UInt8 numberOfInputs, UInt8 numberOfOutputs, UInt8 speakerMode, UInt8 simulationMode, CFDataRef speakerLayout);
	void		ReceiveNumberOfChannels(UInt32 numberOfChannels);
	void		ReceiveLogLevel(bool debugIsOn, UInt32 debugLevel);

	//  Queries
	bool		IsAlive();
	bool		CanBeDefaultDevice(bool inIsInput, bool inIsSystem) const { return false; }

protected:
		// client-server communication
	ZirkoniumHALClientPort			mClient;
	
		// audio state
	UInt32							mMixerNumberOfOutputs;
	UInt32							mOutputChannelMapSize;
	SInt32*							mOutputChannelMap;
	
	ZKMNRSpeakerLayoutSimulator*	mSpeakerLayoutSimulator;
	unsigned						mLoudspeakerMode;
	ZKMNRSimulationMode				mSimulationMode;
	ZKMNRSpeakerLayout*				mSpeakerLayout;
};

#endif