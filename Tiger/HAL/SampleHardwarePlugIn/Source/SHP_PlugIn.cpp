/*	Copyright © 2007 Apple Inc. All Rights Reserved.
	
	Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
			Apple Inc. ("Apple") in consideration of your agreement to the
			following terms, and your use, installation, modification or
			redistribution of this Apple software constitutes acceptance of these
			terms.  If you do not agree with these terms, please do not use,
			install, modify or redistribute this Apple software.
			
			In consideration of your agreement to abide by the following terms, and
			subject to these terms, Apple grants you a personal, non-exclusive
			license, under Apple's copyrights in this original Apple software (the
			"Apple Software"), to use, reproduce, modify and redistribute the Apple
			Software, with or without modifications, in source and/or binary forms;
			provided that if you redistribute the Apple Software in its entirety and
			without modifications, you must retain this notice and the following
			text and disclaimers in all such redistributions of the Apple Software. 
			Neither the name, trademarks, service marks or logos of Apple Inc. 
			may be used to endorse or promote products derived from the Apple
			Software without specific prior written permission from Apple.  Except
			as expressly stated in this notice, no other rights or licenses, express
			or implied, are granted by Apple herein, including but not limited to
			any patent rights that may be infringed by your derivative works or by
			other works in which the Apple Software may be incorporated.
			
			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
			MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
			THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
			FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
			OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
			
			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
			OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
			SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
			INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
			MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
			AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
			STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
			POSSIBILITY OF SUCH DAMAGE.
*/
//=============================================================================
//	Includes
//=============================================================================

//	Self Include
#include "SHP_PlugIn.h"

//	Internal Includes
#include "SHP_Device.h"

//	HPBase Includes
#include "HP_DeviceSettings.h"

//	PublicUtility Includes
#include "CADebugMacros.h"
#include "CAException.h"
#include "CAPropertyAddress.h"

//=============================================================================
//	SHP_PlugIn
//=============================================================================

SHP_PlugIn::SHP_PlugIn(CFUUIDRef inFactoryUUID)
:
	HP_HardwarePlugIn(inFactoryUUID),
	mDevice(NULL)
{
}

SHP_PlugIn::~SHP_PlugIn()
{
}

void	SHP_PlugIn::InitializeWithObjectID(AudioObjectID inObjectID)
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
	ThrowIfError(theError, CAException(theError), "SHP_PlugIn::InitializeWithObjectID: couldn't instantiate the AudioDevice object");
	
	//	make a device object
	mDevice = new SHP_Device(theNewDeviceID, this);
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
	AssertNoError(theError, "SHP_PlugIn::InitializeWithObjectID: got an error telling the HAL a device died");
}

void	SHP_PlugIn::Teardown()
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
		AssertNoError(theError, "SHP_PlugIn::Teardown: got an error telling the HAL a device died");
		
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

bool	SHP_PlugIn::HasProperty(const AudioObjectPropertyAddress& inAddress) const
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

bool	SHP_PlugIn::IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const
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

UInt32	SHP_PlugIn::GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const
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

void	SHP_PlugIn::GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const
{
	switch(inAddress.mSelector)
	{
		case kAudioObjectPropertyName:
			ThrowIf(ioDataSize != GetPropertyDataSize(inAddress, inQualifierDataSize, inQualifierData), CAException(kAudioHardwareBadPropertySizeError), "SHP_PlugIn::GetPropertyData: wrong data size for kAudioObjectPropertyName");
			*static_cast<CFStringRef*>(outData) = CFSTR("com.apple.audio.SampleHardwarePlugIn");
			CFRetain(*static_cast<CFStringRef*>(outData));
			break;
			
		default:
			HP_HardwarePlugIn::GetPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
			break;
	};
}

void	SHP_PlugIn::SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen)
{
	switch(inAddress.mSelector)
	{
		default:
			HP_HardwarePlugIn::SetPropertyData(inAddress, inQualifierDataSize, inQualifierData, inDataSize, inData, inWhen);
			break;
	};
}

extern "C" void*
New_SHP_PlugIn(CFAllocatorRef /*inAllocator*/, CFUUIDRef inRequestedTypeUUID) 
{
	void*	theAnswer = NULL;
	
	if(CFEqual(inRequestedTypeUUID, kAudioHardwarePlugInTypeID))
	{
		SHP_PlugIn*	thePlugIn = new SHP_PlugIn(inRequestedTypeUUID);
		thePlugIn->Retain();
		theAnswer = thePlugIn->GetInterface();
	}
	
	return theAnswer;
}
