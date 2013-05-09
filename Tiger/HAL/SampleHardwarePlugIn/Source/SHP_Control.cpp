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
//==================================================================================================
//	Includes
//==================================================================================================

//	Self Include
#include "SHP_Control.h"

//  Local Includes
#include "SHP_Device.h"
#include "SHP_PlugIn.h"

//  PublicUtility Includes
#include "CACFArray.h"
#include "CACFDictionary.h"
#include "CACFNumber.h"
#include "CACFString.h"
#include "CADebugMacros.h"
#include "CAException.h"

//==================================================================================================
//	SHP_LevelControl
//==================================================================================================

SHP_LevelControl::SHP_LevelControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, SHP_PlugIn* inPlugIn, SHP_Device* inOwningDevice)
:
	HP_LevelControl(inObjectID, inClassID, inPlugIn, inOwningDevice),
	mDevicePropertyScope(inDevicePropertyScope),
	mDevicePropertyElement(inDevicePropertyElement),
	mVolumeCurve(),
	mCurrentRawValue(0)
{
}

SHP_LevelControl::~SHP_LevelControl()
{
}

void	SHP_LevelControl::Initialize()
{
	//	cache the info about the control
	SInt32 theMinRaw = 0;
	SInt32 theMaxRaw = 1024;
	Float32 theMinDB = -90;
	Float32 theMaxDB = 0;
	
	//	set up the volume curve
	mVolumeCurve.ResetRange();
	mVolumeCurve.AddRange(theMinRaw, theMaxRaw, theMinDB, theMaxDB);
	
	//	cache the raw value
	CacheRawValue();
}

void	SHP_LevelControl::Teardown()
{
}

AudioObjectPropertyScope	SHP_LevelControl::GetPropertyScope() const
{
	return mDevicePropertyScope;
}

AudioObjectPropertyElement	SHP_LevelControl::GetPropertyElement() const
{
	return mDevicePropertyElement;
}

Float32	SHP_LevelControl::GetMinimumDBValue() const
{
	return mVolumeCurve.GetMinimumDB();
}

Float32	SHP_LevelControl::GetMaximumDBValue() const
{
	return mVolumeCurve.GetMaximumDB();
}

Float32	SHP_LevelControl::GetDBValue() const
{
	SInt32 theRawValue = GetRawValue();
	Float32 thDBValue = mVolumeCurve.ConvertRawToDB(theRawValue);
	return thDBValue;
}

void	SHP_LevelControl::SetDBValue(Float32 inDBValue)
{
	SInt32 theNewRawValue = mVolumeCurve.ConvertDBToRaw(inDBValue);
	SetRawValue(theNewRawValue);
}

Float32	SHP_LevelControl::GetScalarValue() const
{
	SInt32 theRawValue = GetRawValue();
	Float32 theScalarValue = mVolumeCurve.ConvertRawToScalar(theRawValue);
	return theScalarValue;
}

void	SHP_LevelControl::SetScalarValue(Float32 inScalarValue)
{
	SInt32 theNewRawValue = mVolumeCurve.ConvertScalarToRaw(inScalarValue);
	SetRawValue(theNewRawValue);
}

Float32	SHP_LevelControl::ConverScalarValueToDBValue(Float32 inScalarValue) const
{
	Float32 theDBValue = mVolumeCurve.ConvertScalarToDB(inScalarValue);
	return theDBValue;
}

Float32	SHP_LevelControl::ConverDBValueToScalarValue(Float32 inDBValue) const
{
	Float32 theScalarValue = mVolumeCurve.ConvertDBToScalar(inDBValue);
	return theScalarValue;
}

SInt32	SHP_LevelControl::GetRawValue() const
{
	//	Always get the value from the hardware and cache it in mCurrentRawValue. Note that if
	//	getting the value from the hardware fails for any reason, we just return mCurrentRawValue.
	//	We always just return mCurrentRawValue here because there is no hardware to talk to.
	return mCurrentRawValue;
}

void	SHP_LevelControl::SetRawValue(SInt32 inRawValue)
{
	//	Set the value in hardware. Note that mCurrentRawValue should be updated only if setting the
	//	hardware value is synchronous. Otherwise, mCurrentRawValue will be updated when the hardware
	//	notifies us that the value of the control changed. Here, we just directly set
	//	mCurrentRawValue because there is no hardware.
	if(inRawValue != mCurrentRawValue)
	{
		mCurrentRawValue = inRawValue;
	
		//	we also have to send the change notification
		ValueChanged();
	}
}

void	SHP_LevelControl::CacheRawValue()
{
	//	Set mCurrentRawValue to the value of the hardware. We do nothing here because there is no
	//	hardware.
}

//==================================================================================================
//	SHP_BooleanControl
//==================================================================================================

SHP_BooleanControl::SHP_BooleanControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, SHP_PlugIn* inPlugIn, SHP_Device* inOwningDevice)
:
	HP_BooleanControl(inObjectID, inClassID, inPlugIn, inOwningDevice),
	mDevicePropertyScope(inDevicePropertyScope),
	mDevicePropertyElement(inDevicePropertyElement),
	mCurrentValue(false)
{
}

SHP_BooleanControl::~SHP_BooleanControl()
{
}

void	SHP_BooleanControl::Initialize()
{
	//	cache the value
	CacheValue();
}

void	SHP_BooleanControl::Teardown()
{
}

AudioObjectPropertyScope	SHP_BooleanControl::GetPropertyScope() const
{
	return mDevicePropertyScope;
}

AudioObjectPropertyElement	SHP_BooleanControl::GetPropertyElement() const
{
	return mDevicePropertyElement;
}

bool	SHP_BooleanControl::GetValue() const
{
	//	Always get the value from the hardware and cache it in mCurrentValue. Note that if
	//	getting the value from the hardware fails for any reason, we just return mCurrentValue.
	//	We always just return mCurrentValue here because there is no hardware to talk to.
	return mCurrentValue;
}

void	SHP_BooleanControl::SetValue(bool inValue)
{
	//	Set the value in hardware. Note that mCurrentValue should be updated only if setting the
	//	hardware value is synchronous. Otherwise, mCurrentValue will be updated when the hardware
	//	notifies us that the value of the control changed. Here, we just directly set
	//	mCurrentValue because there is no hardware.
	if(inValue != mCurrentValue)
	{
		mCurrentValue = inValue;
	
		//	we also have to send the change notification
		ValueChanged();
	}
}

void	SHP_BooleanControl::CacheValue()
{
	//	Set mCurrentValue to the value of the hardware. We do nothing here because there is no hardware.
}

//==================================================================================================
//	SHP_SelectorControl
//==================================================================================================

SHP_SelectorControl::SHP_SelectorControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, SHP_PlugIn* inPlugIn, SHP_Device* inOwningDevice)
:
	HP_SelectorControl(inObjectID, inClassID, inPlugIn, inOwningDevice),
	mDevicePropertyScope(inDevicePropertyScope),
	mDevicePropertyElement(inDevicePropertyElement),
	mSelectorMap(),
	mCurrentItemID(0)
{
}

SHP_SelectorControl::~SHP_SelectorControl()
{
}

void	SHP_SelectorControl::Initialize()
{
	//	clear the current items
	mSelectorMap.clear();
	
	//	Insert items into mSelectorMap for all the items in this control. Here, we just stick in a
	//	few fake items.
	for(UInt32 theItemIndex = 0; theItemIndex < 4; ++theItemIndex)
	{
		//	make a name for the item
		CACFString theName(CFStringCreateWithFormat(NULL, NULL, CFSTR("Item %u"), theItemIndex));
		
		//	insert it into the map, using the item index as the item ID
		mSelectorMap.insert(SelectorMap::value_type(theItemIndex, SelectorItem(theName.CopyCFString(), 0)));
	}
	
	//	cache the current item ID
	CacheCurrentItemID();
}

void	SHP_SelectorControl::Teardown()
{
	mSelectorMap.clear();
}

AudioObjectPropertyScope	SHP_SelectorControl::GetPropertyScope() const
{
	return mDevicePropertyScope;
}

AudioObjectPropertyElement	SHP_SelectorControl::GetPropertyElement() const
{
	return mDevicePropertyElement;
}

UInt32	SHP_SelectorControl::GetNumberItems() const
{
	return mSelectorMap.size();
}

UInt32	SHP_SelectorControl::GetCurrentItemID() const
{
	//	Always get the value from the hardware and cache it in mCurrentItemID. Note that if
	//	getting the value from the hardware fails for any reason, we just return mCurrentItemID.
	//	We always just return mCurrentItemID here because there is no hardware to talk to.
	return mCurrentItemID;
}

UInt32	SHP_SelectorControl::GetCurrentItemIndex() const
{
	UInt32 theItemID = GetCurrentItemID();
	return GetItemIndexForID(theItemID);
}

void	SHP_SelectorControl::SetCurrentItemByID(UInt32 inItemID)
{
	//	Set the value in hardware. Note that mCurrentItemID should be updated only if setting the
	//	hardware value is synchronous. Otherwise, mCurrentItemID will be updated when the hardware
	//	notifies us that the value of the control changed. Here, we just directly set
	//	mCurrentItemID because there is no hardware.
	if(inItemID != mCurrentItemID)
	{
		mCurrentItemID = inItemID;
	
		//	we also have to send the change notification
		ValueChanged();
	}
}

void	SHP_SelectorControl::SetCurrentItemByIndex(UInt32 inItemIndex)
{
	UInt32 theItemID = GetItemIDForIndex(inItemIndex);
	SetCurrentItemByID(theItemID);
}

UInt32	SHP_SelectorControl::GetItemIDForIndex(UInt32 inItemIndex) const
{
	ThrowIf(inItemIndex >= mSelectorMap.size(), CAException(kAudioHardwareIllegalOperationError), "SHP_SelectorControl::GetItemIDForIndex: index out of range");
	SelectorMap::const_iterator theIterator = mSelectorMap.begin();
	std::advance(theIterator, inItemIndex);
	return theIterator->first;
}

UInt32	SHP_SelectorControl::GetItemIndexForID(UInt32 inItemID) const
{
	UInt32 theIndex = 0;
	bool wasFound = false;
	SelectorMap::const_iterator theIterator = mSelectorMap.begin();
	while(!wasFound && (theIterator != mSelectorMap.end()))
	{
		if(theIterator->first == inItemID)
		{
			wasFound = true;
		}
		else
		{
			++theIndex;
			std::advance(theIterator, 1);
		}
	}
	ThrowIf(!wasFound, CAException(kAudioHardwareIllegalOperationError), "SHP_SelectorControl::GetItemIndexForID: ID not in selector map");
	return theIndex;
}

CFStringRef	SHP_SelectorControl::CopyItemNameByID(UInt32 inItemID) const
{
	SelectorMap::const_iterator theIterator = mSelectorMap.find(inItemID);
	ThrowIf(theIterator == mSelectorMap.end(), CAException(kAudioHardwareIllegalOperationError), "SHP_SelectorControl::CopyItemNameByID: ID not in selector map");
	
	return (CFStringRef)CFRetain(theIterator->second.mItemName);
}

CFStringRef	SHP_SelectorControl::CopyItemNameByIndex(UInt32 inItemIndex) const
{
	CFStringRef theAnswer = NULL;
	
	if(inItemIndex < mSelectorMap.size())
	{
		SelectorMap::const_iterator theIterator = mSelectorMap.begin();
		std::advance(theIterator, inItemIndex);
		ThrowIf(theIterator == mSelectorMap.end(), CAException(kAudioHardwareIllegalOperationError), "SHP_SelectorControl::CopyItemNameByIndex: index out of range");
		
		theAnswer = (CFStringRef)CFRetain(theIterator->second.mItemName);
	}
		
	return theAnswer;
}

CFStringRef	SHP_SelectorControl::CopyItemNameByIDWithoutLocalizing(UInt32 inItemID) const
{
	return CopyItemNameByID(inItemID);
}

CFStringRef	SHP_SelectorControl::CopyItemNameByIndexWithoutLocalizing(UInt32 inItemIndex) const
{
	return CopyItemNameByIndex(inItemIndex);
}

UInt32	SHP_SelectorControl::GetItemKindByID(UInt32 inItemID) const
{
	SelectorMap::const_iterator theIterator = mSelectorMap.find(inItemID);
	ThrowIf(theIterator == mSelectorMap.end(), CAException(kAudioHardwareIllegalOperationError), "SHP_SelectorControl::GetItemKindByID: ID not in selector map");
	
	return theIterator->second.mItemKind;
}

UInt32	SHP_SelectorControl::GetItemKindByIndex(UInt32 inItemIndex) const
{
	UInt32 theAnswer = 0;
	
	if(inItemIndex < mSelectorMap.size())
	{
		SelectorMap::const_iterator theIterator = mSelectorMap.begin();
		std::advance(theIterator, inItemIndex);
		ThrowIf(theIterator == mSelectorMap.end(), CAException(kAudioHardwareIllegalOperationError), "SHP_SelectorControl::GetItemKindByIndex: index out of range");
		theAnswer = theIterator->second.mItemKind;
	}
	
	return theAnswer;
}

void	SHP_SelectorControl::CacheCurrentItemID()
{
	//	Set mCurrentItemID to the value of the hardware. We do nothing here because there is no hardware.
}

//==================================================================================================
//	SHP_StereoPanControl
//==================================================================================================

SHP_StereoPanControl::SHP_StereoPanControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, UInt32 inLeftChannel, UInt32 inRightChannel, SHP_PlugIn* inPlugIn, SHP_Device* inOwningDevice)
:
	HP_StereoPanControl(inObjectID, inClassID, inPlugIn, inOwningDevice),
	mDevicePropertyScope(inDevicePropertyScope),
	mDevicePropertyElement(inDevicePropertyElement),
	mLeftChannel(inLeftChannel),
	mRightChannel(inRightChannel),
	mFullLeftRawValue(0),
	mCenterRawValue(0),
	mFullRightRawValue(0),
	mCurrentRawValue(0)
{
}

SHP_StereoPanControl::~SHP_StereoPanControl()
{
}

void	SHP_StereoPanControl::Initialize()
{
	//	cache the info about the control
	mFullLeftRawValue = 0;
	mCenterRawValue = 512;
	mFullRightRawValue = 1024;
	
	//	set the value to center, since we don't have any hardware
	mCurrentRawValue = mCenterRawValue;
	
	//	cache the current raw value
	CacheRawValue();
}

void	SHP_StereoPanControl::Teardown()
{
}

AudioObjectPropertyScope	SHP_StereoPanControl::GetPropertyScope() const
{
	return mDevicePropertyScope;
}

AudioObjectPropertyElement	SHP_StereoPanControl::GetPropertyElement() const
{
	return mDevicePropertyElement;
}

Float32	SHP_StereoPanControl::GetValue() const
{
	Float32	theAnswer = 0.0;
	SInt32	theRawValue = GetRawValue();
	Float32	theSpan;
	
	if(theRawValue == mCenterRawValue)
	{
		theAnswer = 0.5;
	}
	else if(theRawValue > mCenterRawValue)
	{
		theSpan = mFullRightRawValue - mCenterRawValue;
		theAnswer = theRawValue - mCenterRawValue;
		theAnswer *= 0.5;
		theAnswer /= theSpan;
		theAnswer += 0.5;
	}
	else
	{
		theSpan = mCenterRawValue - mFullLeftRawValue;
		theAnswer = theRawValue - mFullLeftRawValue;
		theAnswer *= 0.5;
		theAnswer /= theSpan;
	}
	
	return theAnswer;
}

void	SHP_StereoPanControl::SetValue(Float32 inValue)
{
	SInt32 theRawValue = 0;
	Float32 theSpan;
	
	if(inValue == 0.5)
	{
		theRawValue = mCenterRawValue;
	}
	else if(inValue > 0.5)
	{
		theSpan = mFullRightRawValue - mCenterRawValue;
		inValue -= 0.5;
		inValue *= theSpan;
		inValue *= 2.0;
		theRawValue = static_cast<SInt32>(inValue);
		theRawValue += mCenterRawValue;
	}
	else
	{
		theSpan = mCenterRawValue - mFullLeftRawValue;
		inValue *= theSpan;
		inValue *= 2.0;
		theRawValue = static_cast<SInt32>(inValue);
	}
	
	SetRawValue(theRawValue);
}

void	SHP_StereoPanControl::GetChannels(UInt32& outLeftChannel, UInt32& outRightChannel) const
{
	outLeftChannel = mLeftChannel;
	outRightChannel = mRightChannel;
}

SInt32	SHP_StereoPanControl::GetRawValue() const
{
	//	Always get the value from the hardware and cache it in mCurrentRawValue. Note that if
	//	getting the value from the hardware fails for any reason, we just return mCurrentRawValue.
	//	We always just return mCurrentRawValue here because there is no hardware to talk to.
	return mCurrentRawValue;
}

void	SHP_StereoPanControl::SetRawValue(SInt32 inValue)
{
	//	Set the value in hardware. Note that mCurrentRawValue should be updated only if setting the
	//	hardware value is synchronous. Otherwise, mCurrentRawValue will be updated when the hardware
	//	notifies us that the value of the control changed. Here, we just directly set
	//	mCurrentRawValue because there is no hardware.
	if(inValue != mCurrentRawValue)
	{
		mCurrentRawValue = inValue;
	
		//	we also have to send the change notification
		ValueChanged();
	}
}

void	SHP_StereoPanControl::CacheRawValue()
{
	//	Set mCurrentRawValue to the value of the hardware. We do nothing here because there is no
	//	hardware.
}
