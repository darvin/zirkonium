//
//  ZKMRNHALPlugInImpl.h
//  CERN
//
//  Created by Chandrasekhar Ramakrishnan on 28.02.07.
//  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
//

#ifndef __ZKMRNHALPlugInImpl_H__
#define __ZKMRNHALPlugInImpl_H__

#include "ZKMORHALPlugInImplSycamore.h"
#include "ZKMRNHALPlugInProtocol.h"

/// 
///  ZKMRNHALPlugInImpl
///
///  The Zirkonium HAL Plug-In. Note, the plug-in is not instantiated if we are running inside of Zirkonium.
///
class ZKMRNHALPlugInImpl : public ZKMORHALPlugInImplSycamore, public ZirkoniumHALClientPort::ClientPortDelegate {

public:	

	//  CTOR / DTOR
	ZKMRNHALPlugInImpl(AudioHardwarePlugInRef plugIn);
	virtual ~ZKMRNHALPlugInImpl();
	
protected:
	// HAL API Overrides
	OSStatus	Initialize();
	
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

protected:
		// client-server communication
	ZirkoniumHALClientPort		mClient;
	
		// audio state
	UInt32						mMixerNumberOfOutputs;
	UInt32						mOutputChannelMapSize;
	SInt32*						mOutputChannelMap;
	
	ZKMNRSpeakerLayoutSimulator*	mSpeakerLayoutSimulator;
	unsigned						mLoudspeakerMode;
	ZKMNRSimulationMode				mSimulationMode;
	ZKMNRSpeakerLayout*				mSpeakerLayout;
};

#endif