/*
 *  ZKMORHP_ForeignThread.h
 *  Cushion
 *
 *  Created by C. Ramakrishnan on 05.03.08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#if !defined(__ZKMORHP_ForeignThread_h__)
#define __ZKMORHP_ForeignThread_h__

//==================================================================================================
//	Includes
//==================================================================================================

//	System Includes
#if !defined(__COREAUDIO_USE_FLAT_INCLUDES__)
	#include <CoreAudio/CoreAudioTypes.h>
#else
	#include <CoreAudioTypes.h>
#endif

#if TARGET_OS_MAC
	#include <pthread.h>
	#include <unistd.h>
#else
	#error	Unsupported operating system
#endif

///  
///  ZKMORHP_ForeignThread
///
///  ZKMORHP_ForeignThread is an abstraction similar to CAPThread, but for a thread that I did not create. It must be
///  explicitly initialized by clients the first time the client thread runs. 
///
class	ZKMORHP_ForeignThread
{

//	Types
public:
	typedef void*			(*ThreadRoutine)(void* inParameter);
	// Interface for clients of the foreign thread
	class ZKMORHP_ForeignThreadSource 
	{
		public:
			/// return true if need to resynch
		virtual bool	WorkLoopInit() = 0;	
		virtual void	WorkLoopIteration(bool& isInNeedOfResynch) = 0;	
		virtual void	WorkLoopTeardown() = 0;
	};

//	Constants
public:
	enum
	{
#if	TARGET_OS_MAC
							kMinThreadPriority = 1,
							kMaxThreadPriority = 63,
							kDefaultThreadPriority = 31
#endif
	};

//	Construction/Destruction
public:
							ZKMORHP_ForeignThread(ThreadRoutine inThreadRoutine, ZKMORHP_ForeignThreadSource* inParameter);
	virtual					~ZKMORHP_ForeignThread();

//	Properties
public:
#if TARGET_OS_MAC
	pthread_t				GetPThread() const { return mPThread; }
	bool					IsCurrentThread() const { return (0 != mPThread) && (pthread_self() == mPThread); }
	bool					IsRunning() const { return 0 != mPThread; }
#endif

	bool					IsTimeShareThread() const { return !mTimeConstraintSet; }
	bool					IsTimeConstraintThread() const { return mTimeConstraintSet; }

	UInt32					GetPriority() const { return mPriority; }
    UInt32					GetScheduledPriority();
    void					SetPriority(UInt32 inPriority, bool inFixedPriority=false);

	void					GetTimeConstraints(UInt32& outPeriod, UInt32& outComputation, UInt32& outConstraint, bool& outIsPreemptible) const { outPeriod = mPeriod; outComputation = mComputation; outConstraint = mConstraint; outIsPreemptible = mIsPreemptible; }
	void					SetTimeConstraints(UInt32 inPeriod, UInt32 inComputation, UInt32 inConstraint, bool inIsPreemptible);
	void					ClearTimeConstraints() { SetPriority(mPriority); }
	
	bool					WillAutoDelete() const { return mAutoDelete; }
	void					SetAutoDelete(bool b) { mAutoDelete = b; }
		
//	Actions
public:
	virtual void			Start();
	void					InitializeIfNecessary();
	void					RunIteration();
	void					ExternalStop();	

//	Implementation
protected:
#if TARGET_OS_MAC
	static void*			Entry(ZKMORHP_ForeignThread* inCAPThread);
    static UInt32			getScheduledPriority(pthread_t inThread, int inPriorityKind);
#endif

#if	TARGET_OS_MAC
	pthread_t				mPThread;
    UInt32					mSpawningThreadPriority;
#endif
	ThreadRoutine					mThreadRoutine;
	ZKMORHP_ForeignThreadSource*	mThreadParameter;
	
	SInt32					mPriority;
	UInt32					mPeriod;
	UInt32					mComputation;
	UInt32					mConstraint;
	bool					mIsPreemptible;
	bool					mTimeConstraintSet;
    bool					mFixedPriority;
	bool					mAutoDelete;		// delete self when thread terminates
	bool					mIsInitialized;
	bool					mIsInNeedOfResynch;
	bool					mWasLocked;
};

#endif
