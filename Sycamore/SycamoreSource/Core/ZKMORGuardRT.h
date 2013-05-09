/*
 *  ZKMORGuardRT.h
 *  Sycamore
 *
 *  Created by Chandrasekhar Ramakrishnan on 20.05.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __ZKMORGuardRT_h__
#define __ZKMORGuardRT_h__

#include "CAGuard.h"
#include <CoreServices/CoreServices.h>
#include <unistd.h>

///
///  ZKMORGuardRT
///
///  A guard designed to be used in realtime situtations. The functions labeled RT are designed to be
///  used by the realtime thread. They may complete or fail, but they return immediately. The functions
///  labeled NRT are designed to be used in non-realtime threads. They may block.
///
///  TODO -- I'd like to switch the NRT portion to use the guard -- currently, I'm just doing a usleep.
///  
class ZKMORGuardRT {

public:
	//  CTOR / DTOR
	ZKMORGuardRT() : mLockState(kZKMORGuardState_Free) { };
	~ZKMORGuardRT() { }
	
public:
	//  Public Functions
	bool	LockRT() { return CompareAndSwap(kZKMORGuardState_Free, kZKMORGuardState_LockRT, (UInt32 *) &mLockState); }
	void	LockNRT() { while (!CompareAndSwap(kZKMORGuardState_Free, kZKMORGuardState_LockNRT, (UInt32*) &mLockState)) usleep(100); } 
	
	bool	UnlockRT() { return CompareAndSwap(kZKMORGuardState_LockRT, kZKMORGuardState_Free, (UInt32 *) &mLockState); }
	bool	UnlockNRT() { return CompareAndSwap(kZKMORGuardState_LockNRT, kZKMORGuardState_Free, (UInt32 *) &mLockState); }
	
protected:
	//  Internal Enums
	enum { kZKMORGuardState_Free, kZKMORGuardState_LockRT, kZKMORGuardState_LockNRT };
	//  Internal State
	volatile UInt32		mLockState;
};

#endif __ZKMORGuardRT_h__