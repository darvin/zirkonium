/*
 *  ZKMORHP_Stream.cpp
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 */

#include "ZKMORHP_Stream.h"

//	Internal Includes
#include "ZKMORHP_Device.h"
#include "ZKMORHP_PlugIn.h"

//	PublicUtility Includes
#include "CACFArray.h"
#include "CACFDictionary.h"
#include "CACFNumber.h"
#include "CADebugMacros.h"
#include "CAException.h"

//	System Includes
//#include <IOKit/audio/IOAudioDefines.h>
//#include <IOKit/audio/IOAudioTypes.h>

//=============================================================================
//	ZKMORHP_Stream
//=============================================================================

ZKMORHP_Stream::ZKMORHP_Stream(AudioStreamID inAudioStreamID, ZKMORHP_PlugIn* inPlugIn, ZKMORHP_Device* inOwningDevice, bool inIsInput, UInt32 inStartingDeviceChannelNumber)
:
	HP_Stream(inAudioStreamID, inPlugIn, inOwningDevice, inIsInput, inStartingDeviceChannelNumber),
	mPlugIn(inPlugIn),
	mOwningDevice(inOwningDevice),
	mNonMixableFormatSet(false)
{
}

ZKMORHP_Stream::~ZKMORHP_Stream()
{
}

void	ZKMORHP_Stream::Initialize()
{
	//	initialize the super class
	HP_Stream::Initialize();
	
	//	add the available physical formats
	AddAvailablePhysicalFormats();
	
	//	set the initial format, which is mono 32 bit float 
	CAStreamBasicDescription streamFormat;
	streamFormat.SetCanonical(1, false);
	streamFormat.mSampleRate = mOwningDevice->GetSampleRate();
	mFormatList->SetCurrentPhysicalFormat(streamFormat, false);
}

void	ZKMORHP_Stream::Teardown()
{
	//	All we need to do here is make sure that if this app set the format to non-mixable, we
	//	restore it to a mixable format that is closest to the current format.
	if(mNonMixableFormatSet)
	{
		//	get the current format
		AudioStreamBasicDescription theMixableFormat;
		mFormatList->GetCurrentPhysicalFormat(theMixableFormat);
		
		//	find the closest mixable format
		if(theMixableFormat.mFormatID == kAudioFormatLinearPCM)
		{
			//	for linear PCM formats, we just clear the flag
			theMixableFormat.mFormatFlags &= ~kAudioFormatFlagIsNonMixable;
		}
		else
		{
			//	for non-linear PCM formats, we just need to find the best available linear PCM
			//	format with the same sample rate
			theMixableFormat.mFormatID = kAudioFormatLinearPCM;
			theMixableFormat.mFormatFlags = 0;
			theMixableFormat.mBytesPerPacket = 0;
			theMixableFormat.mFramesPerPacket = 1;
			theMixableFormat.mBytesPerFrame = 0;
			theMixableFormat.mChannelsPerFrame = 0;
			theMixableFormat.mBitsPerChannel = 0;
			
			//	ask the format list for the best match
			mFormatList->BestMatchForPhysicalFormat(theMixableFormat);
		}
			
		//	ask the format list for the best match
		mFormatList->BestMatchForPhysicalFormat(theMixableFormat);
		
		//	tell the hardware stream to set the format
		TellHardwareToSetPhysicalFormat(theMixableFormat);
	}

	HP_Stream::Teardown();
}

void	ZKMORHP_Stream::Finalize()
{
	//	Finalize() is called in place of Teardown() when we're being lazy about
	//	cleaning up. The idea is to do as little work as possible here.
	
	//	All we need to do here is make sure that if this app set the format to non-mixable, we
	//	restore it to a mixable format that is closest to the current format.
	if(mNonMixableFormatSet)
	{
		//	get the current format
		AudioStreamBasicDescription theMixableFormat;
		mFormatList->GetCurrentPhysicalFormat(theMixableFormat);
		
		//	find the closest mixable format
		if(theMixableFormat.mFormatID == kAudioFormatLinearPCM)
		{
			//	for linear PCM formats, we just clear the flag
			theMixableFormat.mFormatFlags &= ~kAudioFormatFlagIsNonMixable;
		}
		else
		{
			//	for non-linear PCM formats, we just need to find the best available linear PCM
			//	format with the same sample rate
			theMixableFormat.mFormatID = kAudioFormatLinearPCM;
			theMixableFormat.mFormatFlags = 0;
			theMixableFormat.mBytesPerPacket = 0;
			theMixableFormat.mFramesPerPacket = 1;
			theMixableFormat.mBytesPerFrame = 0;
			theMixableFormat.mChannelsPerFrame = 0;
			theMixableFormat.mBitsPerChannel = 0;
			
			//	ask the format list for the best match
			mFormatList->BestMatchForPhysicalFormat(theMixableFormat);
		}
			
		//	ask the format list for the best match
		mFormatList->BestMatchForPhysicalFormat(theMixableFormat);
		
		//	tell the hardware stream to set the format
		TellHardwareToSetPhysicalFormat(theMixableFormat);
	}
}

bool	ZKMORHP_Stream::HasProperty(const AudioObjectPropertyAddress& inAddress) const
{
	bool theAnswer = false;
	
	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(GetOwningDevice()->GetStateMutex());
	
	//  do the work if we still have to
	switch(inAddress.mSelector)
	{
		default:
			theAnswer = HP_Stream::HasProperty(inAddress);
			break;
	};
	
	return theAnswer;
}

bool	ZKMORHP_Stream::IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const
{
	bool theAnswer = false;
	
	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(GetOwningDevice()->GetStateMutex());
	
	//  do the work if we still have to
	switch(inAddress.mSelector)
	{
		default:
			theAnswer = HP_Stream::IsPropertySettable(inAddress);
			break;
	};
	
	return theAnswer;
}

UInt32	ZKMORHP_Stream::GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const
{
	UInt32	theAnswer = 0;
	
	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(GetOwningDevice()->GetStateMutex());
	
	//  do the work if we still have to
	switch(inAddress.mSelector)
	{
		default:
			theAnswer = HP_Stream::GetPropertyDataSize(inAddress, inQualifierDataSize, inQualifierData);
			break;
	};
	
	return theAnswer;
}

void	ZKMORHP_Stream::GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const
{
	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(GetOwningDevice()->GetStateMutex());
	
	//  do the work if we still have to
	switch(inAddress.mSelector)
	{
		default:
			HP_Stream::GetPropertyData(inAddress, inQualifierDataSize, inQualifierData, ioDataSize, outData);
			break;
	};
}

void	ZKMORHP_Stream::SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen)
{
	ThrowIf(!mOwningDevice->HogModeIsOwnedBySelfOrIsFree(), CAException(kAudioDevicePermissionsError), "ZKMORHP_Stream::SetPropertyData: can't set the property because hog mode is owned by another process");

	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(GetOwningDevice()->GetStateMutex());
	
	bool theNewIsMixable;
	AudioStreamBasicDescription theNewFormat;
	const AudioStreamBasicDescription* theFormatDataPtr = static_cast<const AudioStreamBasicDescription*>(inData);

	switch(inAddress.mSelector)
	{
		//  device properties
		case kAudioDevicePropertySupportsMixing:
			ThrowIf(inDataSize != sizeof(UInt32), CAException(kAudioHardwareBadPropertySizeError), "ZKMORHP_Stream::SetPropertyData: wrong data size for kAudioDevicePropertySupportsMixing");
			theNewIsMixable = *(static_cast<const UInt32*>(inData)) != 0;
			
			//	keep track if this process is setting the format to non-mixable
			if(theNewIsMixable)
			{
				mNonMixableFormatSet = false;
			}
			else
			{
				mNonMixableFormatSet = true;
			}
			
			//	set the new format
			mFormatList->SetIsMixable(theNewIsMixable, true);
			break;
		
		//  stream properties
		case kAudioStreamPropertyVirtualFormat:
			//  aka kAudioDevicePropertyStreamFormat
			ThrowIf(inDataSize != sizeof(AudioStreamBasicDescription), CAException(kAudioHardwareBadPropertySizeError), "ZKMORHP_Stream::SetPropertyData: wrong data size for kAudioStreamPropertyVirtualFormat");
			
			//	make a modifiable copy
			theNewFormat = *theFormatDataPtr;
			
			//	screen the format
			ThrowIf(!mFormatList->SanityCheckVirtualFormat(theNewFormat), CAException(kAudioDeviceUnsupportedFormatError), "ZKMORHP_Stream::SetPropertyData: given format is not supported for kAudioStreamPropertyVirtualFormat");
			
			//	look for a best match to what was asked for
			mFormatList->BestMatchForVirtualFormat(theNewFormat);
			
			//	keep track if this process is setting the format to non-mixable
			if(CAStreamBasicDescription::IsMixable(theNewFormat))
			{
				mNonMixableFormatSet = false;
			}
			else
			{
				mNonMixableFormatSet = true;
			}
			
			//	set the new format
			mFormatList->SetCurrentVirtualFormat(theNewFormat, true);
			break;

		case kAudioStreamPropertyPhysicalFormat:
			ThrowIf(inDataSize != sizeof(AudioStreamBasicDescription), CAException(kAudioHardwareBadPropertySizeError), "ZKMORHP_Stream::SetPropertyData: wrong data size for kAudioStreamPropertyPhysicalFormat");
			
			//	make a modifiable copy
			theNewFormat = *theFormatDataPtr;
			
			//	screen the format
			ThrowIf(!mFormatList->SanityCheckPhysicalFormat(theNewFormat), CAException(kAudioDeviceUnsupportedFormatError), "ZKMORHP_Stream::SetPropertyData: given format is not supported for kAudioStreamPropertyPhysicalFormat");
			
			//	look for a best match to what was asked for
			mFormatList->BestMatchForPhysicalFormat(theNewFormat);
			
			//	keep track if this process is setting the format to non-mixable
			if(CAStreamBasicDescription::IsMixable(theNewFormat))
			{
				mNonMixableFormatSet = false;
			}
			else
			{
				mNonMixableFormatSet = true;
			}
			
			//	set the new format
			mFormatList->SetCurrentPhysicalFormat(theNewFormat, true);
			break;

		default:
			HP_Stream::SetPropertyData(inAddress, inQualifierDataSize, inQualifierData, inDataSize, inData, inWhen);
			break;
	};
}

bool	ZKMORHP_Stream::TellHardwareToSetPhysicalFormat(const AudioStreamBasicDescription& /*inFormat*/)
{
	//	this method is called to tell the hardware to change format. It returns true if the format
	//	change took place immediately, which is the casee for this sample device.
	return true;
}

void	ZKMORHP_Stream::RefreshAvailablePhysicalFormats()
{
	mFormatList->RemoveAllFormats();
	AddAvailablePhysicalFormats();
	SetDefaultPhysicalFormatToCurrent();
	
	
	CAPropertyAddressList theChangedProperties;
	CAPropertyAddress theAddress(kAudioStreamPropertyAvailablePhysicalFormats);
	theChangedProperties.AppendUniqueItem(theAddress);
	theAddress.mSelector = kAudioStreamPropertyAvailableVirtualFormats;
	theChangedProperties.AppendUniqueItem(theAddress);
	theAddress.mSelector = kAudioStreamPropertyPhysicalFormats;
	theChangedProperties.AppendUniqueItem(theAddress);
	theAddress.mSelector = kAudioDevicePropertyStreamFormats;
	theChangedProperties.AppendUniqueItem(theAddress);
	PropertiesChanged(theChangedProperties.GetNumberItems(), theChangedProperties.GetItems());
}

void	ZKMORHP_Stream::SetDefaultPhysicalFormatToCurrent()
{
	CAStreamBasicDescription streamFormat;
	streamFormat.SetCanonical(1, false);
	streamFormat.mSampleRate = mOwningDevice->GetSampleRate();
	
	mFormatList->SetCurrentPhysicalFormat(streamFormat, false);
}

void	ZKMORHP_Stream::AddAvailablePhysicalFormats()
{
	CAStreamBasicDescription streamFormat;
	streamFormat.SetCanonical(1, false);
	streamFormat.mSampleRate = mOwningDevice->GetSampleRate();
	
	// just one format allowed
	AudioStreamRangedDescription thePhysicalFormat;
	thePhysicalFormat.mFormat = streamFormat;
	thePhysicalFormat.mSampleRateRange.mMinimum = streamFormat.mSampleRate;
	thePhysicalFormat.mSampleRateRange.mMaximum = streamFormat.mSampleRate;
	mFormatList->AddPhysicalFormat(thePhysicalFormat);
}
