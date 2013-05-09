/*
 *  ZKMORHP_Prefix.h
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 *
 *  This needs to be a prefix file to any target that build
 *  an AudioHardwarePlugin
 */
 
 /*=============================================================================
	ZKMORHP_Prefix.h

=============================================================================*/
#if !defined(__ZKMORHP_Prefix_h__)
#define __ZKMORHP_Prefix_h__

//=============================================================================
//	Includes
//=============================================================================

//	Deal with AvailabilityMacros.h on Panther and Tiger
#include <AvailabilityMacros.h>

#if !defined(MAC_OS_X_VERSION_10_4)
	//	The HAL's APIs are written for Tiger, but we're compiling on a Panther system. We need to
	//	define enough of what's on Tiger to make things happy.
	#define	MAC_OS_X_VERSION_10_4 1040

	//	The API's make use of AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER, so we need o define it here
	#define AVAILABLE_MAC_OS_X_VERSION_10_4_AND_LATER	WEAK_IMPORT_ATTRIBUTE

#endif

//  System Includes
#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>

//  Standard C Library Includes
#include <stdio.h>

//  Standard C++ Library Includes
#if defined(__cplusplus)
	#include <algorithm>
	#include <functional>
	#include <iterator>
	#include <list>
	#include <map>
	#include <set>
	#include <utility>
	#include <vector>
#endif

//========
//  CR ADDED - Tiger Compatability
//========
#if	(MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5)
typedef AudioDeviceIOProc   AudioDeviceIOProcID;
enum
{
    kAudioDevicePropertyIcon                            = 'icon',
    kAudioDevicePropertyIsHidden                        = 'hidn'
};

/*!
    @defined        kAudioHardwarePlugInInterface4ID
    @discussion     This is the UUID of version 4 of the plug-in interface
                    (E96C3E92-E745-4CB7-BA91-B33C68F2F026).
*/
#define kAudioHardwarePlugInInterface4ID                                                            \
            CFUUIDGetConstantUUIDWithBytes( NULL, 0xE9, 0x6C, 0x3E, 0x92, 0xE7, 0x45, 0x4C, 0xB7,   \
                                            0xBA, 0x91, 0xB3, 0x3C, 0x68, 0xF2, 0xF0, 0x26)

#endif

#endif


