//
//  ZKMRNHP_Plugin.h
//  Zirkonium
//
//  Created by C. Ramakrishnan on 02.04.08.
//  Copyright 2008 Illposed Software. All rights reserved.
//


#if !defined(__ZKMRNHP_Plugin_h__)
#define __ZKMRNHP_Plugin_h__
//=============================================================================
//	Includes
//=============================================================================
//	Includes
//	Super Class Includes
#include "ZKMORHP_PlugIn.h"

//=============================================================================
//	Types
//=============================================================================


//=============================================================================
//	ZKMORHP_PlugIn
//=============================================================================

class ZKMRNHP_Plugin : public ZKMORHP_PlugIn
{

//	Construction/Destruction
public:
					ZKMRNHP_Plugin(CFUUIDRef inFactoryUUID) : ZKMORHP_PlugIn(inFactoryUUID) { }
	virtual			~ZKMRNHP_Plugin() { }
	
protected:
	virtual CFStringRef		CopyPlugInName() const;
	virtual ZKMORHP_Device* CreateDevice(AudioDeviceID deviceID);
};

#endif

