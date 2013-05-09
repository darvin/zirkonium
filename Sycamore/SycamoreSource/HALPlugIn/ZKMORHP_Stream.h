/*
 *  ZKMORHP_Stream.h
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 */

/*=============================================================================
	ZKMORHP_Stream.h

=============================================================================*/
#if !defined(__ZKMORHP_Stream_h__)
#define __ZKMORHP_Stream_h__

//=============================================================================
//	Includes
//=============================================================================

//	Super Class Includes
#include "HP_Stream.h"

//	System Includes
#include <IOKit/IOKitLib.h>

//=============================================================================
//	Types
//=============================================================================

class	ZKMORHP_Device;
class	ZKMORHP_PlugIn;

//=============================================================================
//	ZKMORHP_Stream
//=============================================================================

class ZKMORHP_Stream
:
	public HP_Stream
{

//	Construction/Destruction
public:
						ZKMORHP_Stream(AudioStreamID inAudioStreamID, ZKMORHP_PlugIn* inPlugIn, ZKMORHP_Device* inOwningDevice, bool inIsInput, UInt32 inStartingDeviceChannelNumber);
	virtual				~ZKMORHP_Stream();

	virtual void		Initialize();
	virtual void		Teardown();
	virtual void		Finalize();

//	Attributes
private:
	ZKMORHP_PlugIn*			mPlugIn;
	ZKMORHP_Device*			mOwningDevice;

//	Property Access
public:
	virtual bool		HasProperty(const AudioObjectPropertyAddress& inAddress) const;
	virtual bool		IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const;
	virtual UInt32		GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const;
	virtual void		GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const;
	virtual void		SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen);
	
//	Format Management
public:
	virtual bool		TellHardwareToSetPhysicalFormat(const AudioStreamBasicDescription& inFormat);
	void				RefreshAvailablePhysicalFormats();
	void				SetDefaultPhysicalFormatToCurrent();
	
private:
	void				AddAvailablePhysicalFormats();
	
	bool				mNonMixableFormatSet;

};

#endif
