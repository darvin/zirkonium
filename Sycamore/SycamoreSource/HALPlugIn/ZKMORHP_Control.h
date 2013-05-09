/*
 *  ZKMORHP_Control.h
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 */

/*==================================================================================================
	ZKMORHP_Control.h

==================================================================================================*/
#if !defined(__ZKMORHP_Control_h__)
#define __ZKMORHP_Control_h__

//==================================================================================================
//	Includes
//==================================================================================================

//	Super Class Includes
#include "HP_Control.h"

//	PublicUtility Includes
#include "CAVolumeCurve.h"

//==================================================================================================
//	Types
//==================================================================================================

class	ZKMORHP_Device;
class	ZKMORHP_PlugIn;

//==================================================================================================
//	ZKMORHP_LevelControl
//==================================================================================================

class ZKMORHP_LevelControl
:
	public HP_LevelControl
{

//	Construction/Destruction
public:
										ZKMORHP_LevelControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, ZKMORHP_PlugIn* inPlugIn, ZKMORHP_Device* inOwningDevice);
	virtual								~ZKMORHP_LevelControl();
	
	virtual void						Initialize();
	virtual void						Teardown();

//	Attributes
public:
	virtual AudioObjectPropertyScope	GetPropertyScope() const;
	virtual AudioObjectPropertyElement	GetPropertyElement() const;

	virtual Float32						GetMinimumDBValue() const;
	virtual Float32						GetMaximumDBValue() const;

	virtual Float32						GetDBValue() const;
	virtual void						SetDBValue(Float32 inDBValue);

	virtual Float32						GetScalarValue() const;
	virtual void						SetScalarValue(Float32 inScalarValue);

	virtual Float32						ConverScalarValueToDBValue(Float32 inScalarValue) const;
	virtual Float32						ConverDBValueToScalarValue(Float32 inDBValue) const;
	
//	Implementation
private:
	SInt32								GetRawValue() const;
	void								SetRawValue(SInt32 inRawValue);
	void								CacheRawValue();

	AudioObjectPropertyScope			mDevicePropertyScope;
	AudioObjectPropertyElement			mDevicePropertyElement;
	CAVolumeCurve						mVolumeCurve;
	SInt32								mCurrentRawValue;

};

//==================================================================================================
//	ZKMORHP_BooleanControl
//==================================================================================================

class ZKMORHP_BooleanControl
:
	public HP_BooleanControl
{

//	Construction/Destruction
public:
										ZKMORHP_BooleanControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, ZKMORHP_PlugIn* inPlugIn, ZKMORHP_Device* inOwningDevice);
	virtual								~ZKMORHP_BooleanControl();

	virtual void						Initialize();
	virtual void						Teardown();

//	Attributes
public:
	virtual AudioObjectPropertyScope	GetPropertyScope() const;
	virtual AudioObjectPropertyElement	GetPropertyElement() const;

	virtual bool						GetValue() const;
	virtual void						SetValue(bool inValue);

//	Implementation
private:
	virtual void						CacheValue();

	AudioObjectPropertyScope			mDevicePropertyScope;
	AudioObjectPropertyElement			mDevicePropertyElement;
	bool								mCurrentValue;

};

//==================================================================================================
//	ZKMORHP_SelectorControl
//==================================================================================================

class ZKMORHP_SelectorControl
:
	public HP_SelectorControl
{

//	Construction/Destruction
public:
										ZKMORHP_SelectorControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, ZKMORHP_PlugIn* inPlugIn, ZKMORHP_Device* inOwningDevice);
	virtual								~ZKMORHP_SelectorControl();
	
	virtual void						Initialize();
	virtual void						Teardown();

//	Attributes
public:
	virtual AudioObjectPropertyScope	GetPropertyScope() const;
	virtual AudioObjectPropertyElement	GetPropertyElement() const;

	virtual UInt32						GetNumberItems() const;

	virtual UInt32						GetCurrentItemID() const;
	virtual UInt32						GetCurrentItemIndex() const;
	
	virtual void						SetCurrentItemByID(UInt32 inItemID);
	virtual void						SetCurrentItemByIndex(UInt32 inItemIndex);
	
	virtual UInt32						GetItemIDForIndex(UInt32 inItemIndex) const;
	virtual UInt32						GetItemIndexForID(UInt32 inItemID) const;
	
	virtual CFStringRef					CopyItemNameByID(UInt32 inItemID) const;
	virtual CFStringRef					CopyItemNameByIndex(UInt32 inItemIndex) const;

	virtual CFStringRef					CopyItemNameByIDWithoutLocalizing(UInt32 inItemID) const;
	virtual CFStringRef					CopyItemNameByIndexWithoutLocalizing(UInt32 inItemIndex) const;

	virtual UInt32						GetItemKindByID(UInt32 inItemID) const;
	virtual UInt32						GetItemKindByIndex(UInt32 inItemIndex) const;

//	Implementation
private:
	void								CacheCurrentItemID();
	
	struct SelectorItem
	{
		CFStringRef	mItemName;
		UInt32		mItemKind;
		
		SelectorItem() : mItemName(NULL), mItemKind(0) {}
		SelectorItem(CFStringRef inItemName, UInt32 inItemKind) : mItemName(inItemName), mItemKind(inItemKind) {}
		SelectorItem(const SelectorItem& inItem) : mItemName(inItem.mItemName), mItemKind(inItem.mItemKind) { if(mItemName != NULL) { CFRetain(mItemName); } }
		SelectorItem&	operator=(const SelectorItem& inItem) { if(mItemName != NULL) { CFRelease(mItemName); } mItemName = inItem.mItemName; if(mItemName != NULL) { CFRetain(mItemName); } mItemKind = inItem.mItemKind; return *this; }
		~SelectorItem() { if(mItemName != NULL) { CFRelease(mItemName); } }
	};
	typedef std::map<UInt32, SelectorItem>	SelectorMap;
	
	AudioObjectPropertyScope			mDevicePropertyScope;
	AudioObjectPropertyElement			mDevicePropertyElement;
	SelectorMap							mSelectorMap;
	UInt32								mCurrentItemID;

};

//==================================================================================================
//	ZKMORHP_StereoPanControl
//==================================================================================================

class ZKMORHP_StereoPanControl
:
	public HP_StereoPanControl
{

//	Construction/Destruction
public:
										ZKMORHP_StereoPanControl(AudioObjectID inObjectID, AudioClassID inClassID, AudioObjectPropertyScope inDevicePropertyScope, AudioObjectPropertyElement inDevicePropertyElement, UInt32 inLeftChannel, UInt32 inRightChannel, ZKMORHP_PlugIn* inPlugIn, ZKMORHP_Device* inOwningDevice);
	virtual								~ZKMORHP_StereoPanControl();

	virtual void						Initialize();
	virtual void						Teardown();

//	Attributes
public:
	virtual AudioObjectPropertyScope	GetPropertyScope() const;
	virtual AudioObjectPropertyElement	GetPropertyElement() const;

	virtual Float32						GetValue() const;
	virtual void						SetValue(Float32 inValue);
	virtual void						GetChannels(UInt32& outLeftChannel, UInt32& outRightChannel) const;

//	Implementation
private:
	virtual SInt32						GetRawValue() const;
	virtual void						SetRawValue(SInt32 inValue);
	virtual void						CacheRawValue();
	
	AudioObjectPropertyScope			mDevicePropertyScope;
	AudioObjectPropertyElement			mDevicePropertyElement;
	UInt32								mLeftChannel;
	UInt32								mRightChannel;
	SInt32								mFullLeftRawValue;
	SInt32								mCenterRawValue;
	SInt32								mFullRightRawValue;
	SInt32								mCurrentRawValue;

};

#endif
