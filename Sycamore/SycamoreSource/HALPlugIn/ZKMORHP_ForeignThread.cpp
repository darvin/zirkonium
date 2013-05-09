/*
 *  ZKMORHP_ForeignThread.cpp
 *  Cushion
 *
 *  Created by C. Ramakrishnan on 05.03.08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#include "ZKMORHP_ForeignThread.h"


//	PublicUtility Includes
#include "CADebugMacros.h"
#include "CAException.h"

//	System Includes
#if	TARGET_OS_MAC
	#include <mach/mach.h>
#endif

//	Standard Library Includes
#include <stdio.h>

//==================================================================================================
//	ZKMORHP_ForeignThread
//==================================================================================================

// returns the thread's priority as it was last set by the API
#define CAPTHREAD_SET_PRIORITY				0
// returns the thread's priority as it was last scheduled by the Kernel
#define CAPTHREAD_SCHEDULED_PRIORITY		1

ZKMORHP_ForeignThread::ZKMORHP_ForeignThread(ThreadRoutine inThreadRoutine, ZKMORHP_ForeignThreadSource* inParameter)
:
#if TARGET_OS_MAC
	mPThread(0),
    mSpawningThreadPriority(getScheduledPriority(pthread_self(), CAPTHREAD_SET_PRIORITY)),
#endif
	mThreadRoutine(inThreadRoutine),
	mThreadParameter(inParameter),
	mPriority(kDefaultThreadPriority),
	mPeriod(0),
	mComputation(0),
	mConstraint(0),
	mIsPreemptible(true),
	mTimeConstraintSet(false),
	mFixedPriority(false),
	mAutoDelete(false),
	mIsInitialized(false)
{
}

ZKMORHP_ForeignThread::~ZKMORHP_ForeignThread()
{
}

UInt32	ZKMORHP_ForeignThread::GetScheduledPriority()
{
#if TARGET_OS_MAC
    return ZKMORHP_ForeignThread::getScheduledPriority( mPThread, CAPTHREAD_SCHEDULED_PRIORITY );
#endif
}

void	ZKMORHP_ForeignThread::SetPriority(UInt32 inPriority, bool inFixedPriority)
{
	mPriority = inPriority;
	mTimeConstraintSet = false;
	mFixedPriority = inFixedPriority;
#if TARGET_OS_MAC
	if(mPThread != 0)
	{
		
		if (mFixedPriority)
		{
			thread_extended_policy_data_t		theFixedPolicy;
			theFixedPolicy.timeshare = false;	// set to true for a non-fixed thread
			AssertNoError(thread_policy_set(pthread_mach_thread_np(mPThread), THREAD_EXTENDED_POLICY, (thread_policy_t)&theFixedPolicy, THREAD_EXTENDED_POLICY_COUNT), "ZKMORHP_ForeignThread::SetPriority: failed to set the fixed-priority policy");
		}
        // We keep a reference to the spawning thread's priority around (initialized in the constructor), 
        // and set the importance of the child thread relative to the spawning thread's priority.
        thread_precedence_policy_data_t		thePrecedencePolicy;
        
        thePrecedencePolicy.importance = mPriority - mSpawningThreadPriority;
        AssertNoError(thread_policy_set(pthread_mach_thread_np(mPThread), THREAD_PRECEDENCE_POLICY, (thread_policy_t)&thePrecedencePolicy, THREAD_PRECEDENCE_POLICY_COUNT), "ZKMORHP_ForeignThread::SetPriority: failed to set the precedence policy");
    } 
#endif
}

void	ZKMORHP_ForeignThread::SetTimeConstraints(UInt32 inPeriod, UInt32 inComputation, UInt32 inConstraint, bool inIsPreemptible)
{
	mPeriod = inPeriod;
	mComputation = inComputation;
	mConstraint = inConstraint;
	mIsPreemptible = inIsPreemptible;
	mTimeConstraintSet = true;
#if TARGET_OS_MAC
	if(mPThread != 0)
	{
		thread_time_constraint_policy_data_t thePolicy;
		thePolicy.period = mPeriod;
		thePolicy.computation = mComputation;
		thePolicy.constraint = mConstraint;
		thePolicy.preemptible = mIsPreemptible;
		AssertNoError(thread_policy_set(pthread_mach_thread_np(mPThread), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&thePolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT), "ZKMORHP_ForeignThread::SetTimeConstraints: thread_policy_set failed");
	}
#endif
}

void	ZKMORHP_ForeignThread::Start()
{
#if TARGET_OS_MAC
	Assert(mPThread == 0, "ZKMORHP_ForeignThread::Start: can't start because the thread is already running");
	if(mPThread == 0)
	{
		OSStatus			theResult;
		pthread_attr_t		theThreadAttributes;
		
		theResult = pthread_attr_init(&theThreadAttributes);
		ThrowIf(theResult != 0, CAException(theResult), "ZKMORHP_ForeignThread::Start: Thread attributes could not be created.");
		
		theResult = pthread_attr_setdetachstate(&theThreadAttributes, PTHREAD_CREATE_DETACHED);
		ThrowIf(theResult != 0, CAException(theResult), "ZKMORHP_ForeignThread::Start: A thread could not be created in the detached state.");
		
		theResult = pthread_create(&mPThread, &theThreadAttributes, (ThreadRoutine)ZKMORHP_ForeignThread::Entry, this);
		ThrowIf(theResult != 0 || !mPThread, CAException(theResult), "ZKMORHP_ForeignThread::Start: Could not create a thread.");
		
		pthread_attr_destroy(&theThreadAttributes);
		
	}
#endif
}

void	ZKMORHP_ForeignThread::InitializeIfNecessary()
{
	if (mIsInitialized) return;
	mIsInitialized = true;
	mPThread = pthread_self();
	mPriority = GetScheduledPriority();
	
	mIsInNeedOfResynch = mThreadParameter->WorkLoopInit();
}

;
void	ZKMORHP_ForeignThread::RunIteration()
{
	mThreadParameter->WorkLoopIteration(mIsInNeedOfResynch);
}

void	ZKMORHP_ForeignThread::ExternalStop()
{
	mIsInitialized = false;
	mThreadParameter->WorkLoopTeardown();
}

#if TARGET_OS_MAC

void*	ZKMORHP_ForeignThread::Entry(ZKMORHP_ForeignThread* inCAPThread)
{
	void* theAnswer = NULL;

	try 
	{
		if(inCAPThread->mTimeConstraintSet)
		{
			inCAPThread->SetTimeConstraints(inCAPThread->mPeriod, inCAPThread->mComputation, inCAPThread->mConstraint, inCAPThread->mIsPreemptible);
		}
		else
		{
			inCAPThread->SetPriority(inCAPThread->mPriority, inCAPThread->mFixedPriority);
		}

		if(inCAPThread->mThreadRoutine != NULL)
		{
			theAnswer = inCAPThread->mThreadRoutine(inCAPThread->mThreadParameter);
		}
	}
	catch (...)
	{
		// what should be done here?
	}
	inCAPThread->mPThread = 0;
	if (inCAPThread->mAutoDelete)
		delete inCAPThread;
	return theAnswer;
}

UInt32 ZKMORHP_ForeignThread::getScheduledPriority(pthread_t inThread, int inPriorityKind)
{
    thread_basic_info_data_t			threadInfo;
	policy_info_data_t					thePolicyInfo;
	unsigned int						count;

	if (inThread == NULL)
		return 0;
    
    // get basic info
    count = THREAD_BASIC_INFO_COUNT;
    thread_info (pthread_mach_thread_np (inThread), THREAD_BASIC_INFO, (thread_info_t)&threadInfo, &count);
    
	switch (threadInfo.policy) {
		case POLICY_TIMESHARE:
			count = POLICY_TIMESHARE_INFO_COUNT;
			thread_info(pthread_mach_thread_np (inThread), THREAD_SCHED_TIMESHARE_INFO, (thread_info_t)&(thePolicyInfo.ts), &count);
            if (inPriorityKind == CAPTHREAD_SCHEDULED_PRIORITY) {
                return thePolicyInfo.ts.cur_priority;
            }
            return thePolicyInfo.ts.base_priority;
            break;
            
        case POLICY_FIFO:
			count = POLICY_FIFO_INFO_COUNT;
			thread_info(pthread_mach_thread_np (inThread), THREAD_SCHED_FIFO_INFO, (thread_info_t)&(thePolicyInfo.fifo), &count);
            if ( (thePolicyInfo.fifo.depressed) && (inPriorityKind == CAPTHREAD_SCHEDULED_PRIORITY) ) {
                return thePolicyInfo.fifo.depress_priority;
            }
            return thePolicyInfo.fifo.base_priority;
            break;
            
		case POLICY_RR:
			count = POLICY_RR_INFO_COUNT;
			thread_info(pthread_mach_thread_np (inThread), THREAD_SCHED_RR_INFO, (thread_info_t)&(thePolicyInfo.rr), &count);
			if ( (thePolicyInfo.rr.depressed) && (inPriorityKind == CAPTHREAD_SCHEDULED_PRIORITY) ) {
                return thePolicyInfo.rr.depress_priority;
            }
            return thePolicyInfo.rr.base_priority;
            break;
	}
    
    return 0;
}

#endif