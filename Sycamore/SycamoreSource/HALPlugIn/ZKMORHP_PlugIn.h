/*
 *  ZKMORHP_PlugIn.h
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 */

#if !defined(__ZKMORHP_PlugIn_h__)
#define __ZKMORHP_PlugIn_h__
//=============================================================================
//	Includes
//=============================================================================
//	Includes
//	Super Class Includes
#include "HP_HardwarePlugIn.h"

//=============================================================================
//	Types
//=============================================================================

class   ZKMORHP_Device;

//=============================================================================
//	ZKMORHP_PlugIn
//=============================================================================

class ZKMORHP_PlugIn : public	HP_HardwarePlugIn
{

//	Construction/Destruction
public:
					ZKMORHP_PlugIn(CFUUIDRef inFactoryUUID);
	virtual			~ZKMORHP_PlugIn();

	virtual void	InitializeWithObjectID(AudioObjectID inObjectID);
	virtual void	Teardown();

//	Property Access
public:
	virtual bool	HasProperty(const AudioObjectPropertyAddress& inAddress) const;
	virtual bool	IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const;
	virtual UInt32	GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const;
	virtual void	GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const;
	virtual void	SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen);
	
protected:
	virtual CFStringRef		CopyPlugInName() const = 0;
	virtual ZKMORHP_Device* CreateDevice(AudioDeviceID deviceID) = 0;

//	ZKMORHP_SingleDevice Support
private:
	ZKMORHP_Device*		mDevice;

};

#endif
