/*
 *  ZKMORHP_PlugIn.cpp
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 */

#include "ZKMORHP_PlugIn.h"

//	Internal Includes
#include "ZKMORHP_Device.h"

//	HPBase Includes
#include "HP_DeviceSettings.h"

//	PublicUtility Includes
#include "CADebugMacros.h"
#include "CAException.h"
#include "CAPropertyAddress.h"

//=============================================================================
//	ZKMORHP_PlugIn
//=============================================================================

ZKMORHP_PlugIn::ZKMORHP_PlugIn(CFUUIDRef inFactoryUUID)
:
	HP_HardwarePlugIn(inFactoryUUID),
	mDevice(NULL)
{
}

ZKMORHP_PlugIn::~ZKMORHP_PlugIn()
{
}

void	ZKMORHP_PlugIn::InitializeWithObjectID(AudioObjectID inObjectID)
{
	//	initialize the super class
	HP_HardwarePlugIn::InitializeWithObjectID(inObjectID);
	
	//	instantiate a new AudioDevice object in the HAL
	AudioDeviceID theNewDeviceID = 0;
#if	(MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4)
	OSStatus theError = AudioHardwareClaimAudioDeviceID(GetInterface(), &theNewDeviceID);
#else
	OSStatus theError = AudioObjectCreate(GetInterface(), kAudioObjectSystemObject, kAudioDeviceClassID, &theNewDeviceID);
#endif
	ThrowIfError(theError, CAException(theError), "ZKMORHP_PlugIn::InitializeWithObjectID: couldn't instantiate the AudioDevice object");
	
	//	make a device object
	mDevice = CreateDevice(theNewDeviceID);
	mDevice->Initialize();
	
	//	restore it's settings if necessary
	UInt32 isMaster = 0;
	UInt32 theSize = sizeof(UInt32);
	AudioHardwareGetProperty(kAudioHardwarePropertyProcessIsMaster, &theSize, &isMaster);
	if(isMaster != 0)
	{
		HP_DeviceSettings::RestoreFromPrefs(*mDevice, HP_DeviceSettings::sStandardControlsToSave, HP_DeviceSettings::kStandardNumberControlsToSave);
	}

	//	set the object state mutex
	HP_Object::SetObjectStateMutexForID(theNewDeviceID, mDevice->GetObjectStateMutex());

	//	tell the HAL about the device
#if	(MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4)
	theError = AudioHardwareDevicesCreated(GetInterface(), 1, &theNewDeviceID);
#else
	theError = AudioObjectsPublishedAndDied(GetInterface(), kAudioObjectSystemObject, 1, &theNewDeviceID, 0, NULL);
#endif
	AssertNoError(theError, "ZKMORHP_PlugIn::InitializeWithObjectID: got an error telling the HAL a device died");
}

void	ZKMORHP_PlugIn::Teardown()
{
	//  first figure out if this is being done as part of the process being torn down
	UInt32 isInitingOrExiting = 0;
	UInt32 theSize = sizeof(UInt32);
	AudioHardwareGetProperty(kAudioHardwarePropertyIsInitingOrExiting, &theSize, &isInitingOrExiting);

	//  next figure out if this is the master process
	UInt32 isMaster = 0;
	theSize = sizeof(UInt32);
	AudioHardwareGetProperty(kAudioHardwarePropertyProcessIsMaster, &theSize, &isMaster);

	//  do the full teardown if this is outside of the process being torn down or this is the master process
	if((isInitingOrExiting == 0) || (isMaster != 0))
	{
		//	stop all IO on the device
		mDevice->Do_StopAllIOProcs();
		
		//	send the necessary IsAlive notifications
		CAPropertyAddress theIsAliveAddress(kAudioDevicePropertyDeviceIsAlive);
		mDevice->PropertiesChanged(1, &theIsAliveAddress);
		
		//	save it's settings if necessary
		if(isMaster != 0)
		{
			HP_DeviceSettings::SaveToPrefs(*mDevice, HP_DeviceSettings::sStandardControlsToSave, HP_DeviceSettings::kStandardNumberControlsToSave);
		}

		//	tell the HAL that the device has gone away
		AudioObjectID theObjectID = mDevice->GetObjectID();
#if	(MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_4)
		OSStatus theError = AudioHardwareDevicesDied(GetInterface(), 1, &theObjectID);
#else
		OSStatus theError = AudioObjectsPublishedAndDied(GetInterface(), kAudioObjectSystemObject, 0, NULL, 1, &theObjectID);
#endif
		AssertNoError(theError, "ZKMORHP_PlugIn::Teardown: got an error telling the HAL a device died");
		
		//	remove the object state mutex
		HP_Object::SetObjectStateMutexForID(theObjectID, NULL);

		//  toss it
		mDevice->Teardown();
		delete mDevice;
		mDevice = NULL;

		//	teardown the super class
		HP_HardwarePlugIn::Teardown();
	}
	else
	{
		//  otherwise, only stop the IOProcs
		mDevice->Do_StopAllIOProcs();
		
		//	finalize (rather than tear down) the devices
		mDevice->Finalize();
		
		//	and leave the rest to die with the process
	}
}

bool	ZKMORHP_PlugIn::HasProperty(const AudioObjectPropertyAddress& inAddress) const
{
	//	initialize the return value
	bool theAnswer = false;
	
	switch(inAddress.mSelector)
	{
		case kAudioObjectPropertyName:
			theAnswer = true;
			break;
			
		default:
			theAnswer = HP_HardwarePlugIn::HasProperty(inAddress);
			break;
	};
	
	return theAnswer;
}

bool	ZKMORHP_PlugIn::IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const
{
	bool theAnswer = false;
	
	switch(inAddress.mSelector)
	{
		case kAudioObjectPropertyName:
			theAnswer = false;
			break;
			
		default:
			theAnswer = HP_HardwarePlugIn::IsPropertySettable(inAddress);
			break;
	};
	
	return theAnswer;
}

UInt32	ZKMORHP_PlugIn::GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const
{
	UInt32 theAnswer = 0;
	
	switch(inAddress.mSelector)
	{
		case kAudioObjectPropertyName:
			theAnswer = sizeof(CFStringRef);
			break;
			
		default:
			theAnswer = HP_HardwarePlugIn::GetPropertyDataSize(inAddress, inQualifierDataSize, inQualifierData);
			break;
	};
	
	return theAnswer;
}

void	ZKMORHP_PlugIn::GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const
{
	switch(inAddress.mSelector)
	{
		case kAudioObjectPropertyName:
			ThrowIf(ioDataSize != GetPropertyDataSize(inAddress, inQualifierDataSize, inQualifierData), CAException(kAudioHardwareBadPropertySizeError), "ZKMORHP_PlugIn::GetPropertyData: wrong data size for kAudioObjectPropertyName");
			*static_cast<CFStringRef*>(outData) = CopyPlugInName();
			break;
			
		default:
			HP_HardwarePlugIn::GetPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
			break;
	};
}

void	ZKMORHP_PlugIn::SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen)
{
	switch(inAddress.mSelector)
	{
		default:
			HP_HardwarePlugIn::SetPropertyData(inAddress, inQualifierDataSize, inQualifierData, inDataSize, inData, inWhen);
			break;
	};
}

