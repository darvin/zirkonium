/*
 *  ZKMORHP_IOThreadSlave.h
 *  Cushion
 *
 *  Created by C. Ramakrishnan on 05.03.08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */


#if !defined(__ZKMORHP_IOThreadSlave_h__)
#define __ZKMORHP_IOThreadSlave_h__

//==================================================================================================
//	Includes
//==================================================================================================

//	PublicUtility Includes
#include "CAGuard.h"
#include "ZKMORHP_ForeignThread.h"

#if	CoreAudio_Debug
//	#define	Log_SchedulingLatency	1
#endif

//=============================================================================
//	Types
//=============================================================================

class	HP_Device;

#if Log_SchedulingLatency
	class	CALatencyLog;
#endif

//==================================================================================================
//	ZKMORHP_IOThreadSlave
//==================================================================================================

class ZKMORHP_IOThreadSlave : ZKMORHP_ForeignThread::ZKMORHP_ForeignThreadSource
{

//	Constants
public:
	enum
	{
						kNotRunningPhase	= 0,
						kInitializingPhase	= 1,
						kRunningPhase		= 2,
						kTeardownPhase		= 3
	};

//	Construction/Destruction
public:
						ZKMORHP_IOThreadSlave(HP_Device* inDevice);
	virtual				~ZKMORHP_IOThreadSlave();
	
//	Operations
public:
	CAGuard&			GetIOGuard() { return mIOGuard; }
	CAGuard*			GetIOGuardPtr() { return &mIOGuard; }
	UInt32				GetIOCycleNumber() const { return mIOCycleCounter; }
	UInt64				GetOverloadCounter() const { return mOverloadCounter; }
	Float32				GetIOCycleUsage() const;
	void				SetIOCycleUsage(Float32 inIOCycleUsage);
	UInt32				GetWorkLoopPhase() const;
	bool				IsWorkLoopRunning() const { return (mWorkLoopPhase == kInitializingPhase) || (mWorkLoopPhase == kRunningPhase); }
	bool				HasBeenStopped() const;
	bool				IsCurrentThread() const;
	void				Start();
	void				Stop();
	void				Resynch(AudioTimeStamp* ioCurrentTime, bool inSignalIOThread);
	void				GetCurrentPosition(AudioTimeStamp& outTime) const;
	Float64				GetAnchorSampleTime() const { return mAnchorTime.mSampleTime; }

//  Support for externally driven work loop	
	ZKMORHP_ForeignThread&	GetForeignThread() { return mIOThread; }
		/// return true if need to resynch
	bool				WorkLoopInit();	
	void				WorkLoopIteration(bool& isInNeedOfResynch);	
	void				WorkLoopTeardown();

//	Implementation
protected:
	void				WorkLoop();
	
	void				SetTimeConstraints();
	void				ClearTimeConstraints();
	bool				CalculateNextWakeUpTime(const AudioTimeStamp& inCurrentTime, AudioTimeStamp& outNextWakeUpTime, bool inMustResynch, bool& inIOGuardWasLocked);
	bool				PerformIO(const AudioTimeStamp& inCurrentTime);

	static void*		ThreadEntry(ZKMORHP_IOThreadSlave* inIOThread);
	
	HP_Device*			mDevice;
	ZKMORHP_ForeignThread	mIOThread;
	CAGuard				mIOGuard;
	Float32				mIOCycleUsage;
	AudioTimeStamp		mAnchorTime;
	Float64				mFrameCounter;
	UInt32				mIOCycleCounter;
	UInt32				mOverloadCounter;
	UInt32				mWorkLoopPhase;
	volatile bool		mStopWorkLoop;
	
	#if Log_SchedulingLatency
		CALatencyLog*	mLatencyLog;
		UInt64			mAllowedLatency;
	#endif
	
};

#endif
