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
#include "SHP_Stream.h"

//	Internal Includes
#include "SHP_Device.h"
#include "SHP_PlugIn.h"

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
//	SHP_Stream
//=============================================================================

SHP_Stream::SHP_Stream(AudioStreamID inAudioStreamID, SHP_PlugIn* inPlugIn, SHP_Device* inOwningDevice, bool inIsInput, UInt32 inStartingDeviceChannelNumber)
:
	HP_Stream(inAudioStreamID, inPlugIn, inOwningDevice, inIsInput, inStartingDeviceChannelNumber),
	mSHPPlugIn(inPlugIn),
	mOwningSHPDevice(inOwningDevice),
	mNonMixableFormatSet(false)
{
}

SHP_Stream::~SHP_Stream()
{
}

void	SHP_Stream::Initialize()
{
	//	initialize the super class
	HP_Stream::Initialize();
	
	//	add the available physical formats
	AddAvailablePhysicalFormats();
	
	//	set the initial format, which is 16 bit stereo
	AudioStreamBasicDescription thePhysicalFormat;
	thePhysicalFormat.mSampleRate = 44100;
	thePhysicalFormat.mFormatID = kAudioFormatLinearPCM;
	thePhysicalFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
	thePhysicalFormat.mBytesPerPacket = 4;
	thePhysicalFormat.mFramesPerPacket = 1;
	thePhysicalFormat.mBytesPerFrame = 4;
	thePhysicalFormat.mChannelsPerFrame = 2;
	thePhysicalFormat.mBitsPerChannel = 16;
	mFormatList->SetCurrentPhysicalFormat(thePhysicalFormat, false);
}

void	SHP_Stream::Teardown()
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

void	SHP_Stream::Finalize()
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

bool	SHP_Stream::HasProperty(const AudioObjectPropertyAddress& inAddress) const
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

bool	SHP_Stream::IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const
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

UInt32	SHP_Stream::GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const
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

void	SHP_Stream::GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const
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

void	SHP_Stream::SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen)
{
	ThrowIf(!mOwningSHPDevice->HogModeIsOwnedBySelfOrIsFree(), CAException(kAudioDevicePermissionsError), "SHP_Stream::SetPropertyData: can't set the property because hog mode is owned by another process");

	//	take and hold the state mutex
	CAMutex::Locker theStateMutex(GetOwningDevice()->GetStateMutex());
	
	bool theNewIsMixable;
	AudioStreamBasicDescription theNewFormat;
	const AudioStreamBasicDescription* theFormatDataPtr = static_cast<const AudioStreamBasicDescription*>(inData);

	switch(inAddress.mSelector)
	{
		//  device properties
		case kAudioDevicePropertySupportsMixing:
			ThrowIf(inDataSize != sizeof(UInt32), CAException(kAudioHardwareBadPropertySizeError), "SHP_Stream::SetPropertyData: wrong data size for kAudioDevicePropertySupportsMixing");
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
			ThrowIf(inDataSize != sizeof(AudioStreamBasicDescription), CAException(kAudioHardwareBadPropertySizeError), "SHP_Stream::SetPropertyData: wrong data size for kAudioStreamPropertyVirtualFormat");
			
			//	make a modifiable copy
			theNewFormat = *theFormatDataPtr;
			
			//	screen the format
			ThrowIf(!mFormatList->SanityCheckVirtualFormat(theNewFormat), CAException(kAudioDeviceUnsupportedFormatError), "SHP_Stream::SetPropertyData: given format is not supported for kAudioStreamPropertyVirtualFormat");
			
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
			ThrowIf(inDataSize != sizeof(AudioStreamBasicDescription), CAException(kAudioHardwareBadPropertySizeError), "SHP_Stream::SetPropertyData: wrong data size for kAudioStreamPropertyPhysicalFormat");
			
			//	make a modifiable copy
			theNewFormat = *theFormatDataPtr;
			
			//	screen the format
			ThrowIf(!mFormatList->SanityCheckPhysicalFormat(theNewFormat), CAException(kAudioDeviceUnsupportedFormatError), "SHP_Stream::SetPropertyData: given format is not supported for kAudioStreamPropertyPhysicalFormat");
			
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

bool	SHP_Stream::TellHardwareToSetPhysicalFormat(const AudioStreamBasicDescription& /*inFormat*/)
{
	//	this method is called to tell the hardware to change format. It returns true if the format
	//	change took place immediately, which is the casee for this sample device.
	return true;
}

void	SHP_Stream::RefreshAvailablePhysicalFormats()
{
	mFormatList->RemoveAllFormats();
	AddAvailablePhysicalFormats();
	
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

void	SHP_Stream::AddAvailablePhysicalFormats()
{
	//	basically, for this sample device, we're only going add two formats
	AudioStreamRangedDescription thePhysicalFormat;
	
	//	the first is 16 bit stereo
	thePhysicalFormat.mFormat.mSampleRate = 44100;
	thePhysicalFormat.mSampleRateRange.mMinimum = 44100;
	thePhysicalFormat.mSampleRateRange.mMaximum = 44100;
	thePhysicalFormat.mFormat.mFormatID = kAudioFormatLinearPCM;
	thePhysicalFormat.mFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
	thePhysicalFormat.mFormat.mBytesPerPacket = 4;
	thePhysicalFormat.mFormat.mFramesPerPacket = 1;
	thePhysicalFormat.mFormat.mBytesPerFrame = 4;
	thePhysicalFormat.mFormat.mChannelsPerFrame = 2;
	thePhysicalFormat.mFormat.mBitsPerChannel = 16;
	mFormatList->AddPhysicalFormat(thePhysicalFormat);
	
	//	the other is 24 bit packed in 32 bit stereo
	thePhysicalFormat.mFormat.mSampleRate = 44100;
	thePhysicalFormat.mSampleRateRange.mMinimum = 44100;
	thePhysicalFormat.mSampleRateRange.mMaximum = 44100;
	thePhysicalFormat.mFormat.mFormatID = kAudioFormatLinearPCM;
	thePhysicalFormat.mFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kLinearPCMFormatFlagIsAlignedHigh;
	thePhysicalFormat.mFormat.mBytesPerPacket = 8;
	thePhysicalFormat.mFormat.mFramesPerPacket = 1;
	thePhysicalFormat.mFormat.mBytesPerFrame = 8;
	thePhysicalFormat.mFormat.mChannelsPerFrame = 2;
	thePhysicalFormat.mFormat.mBitsPerChannel = 24;
	mFormatList->AddPhysicalFormat(thePhysicalFormat);
}
