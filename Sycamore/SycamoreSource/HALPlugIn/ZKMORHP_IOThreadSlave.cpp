/*
 *  ZKMORHP_IOThreadSlave.cpp
 *  Cushion
 *
 *  Created by C. Ramakrishnan on 05.03.08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#include "ZKMORHP_IOThreadSlave.h"
#include <Syncretism/ZKMORLogger.h>


//==================================================================================================
//	Includes
//==================================================================================================

//	Self Include
#include "HP_IOThread.h"

//	Local Includes
#include "HP_Device.h"
#include "HP_IOCycleTelemetry.h"

//	PublicUtility Includes
#include "CAAudioTimeStamp.h"
#include "CADebugger.h"
#include "CADebugMacros.h"
#include "CAException.h"
#include "CAHostTimeBase.h"

#if Log_SchedulingLatency
	#include "CALatencyLog.h";
#endif

//#define	Offset_For_Input	1

#if CoreAudio_Debug
//	#define	Log_Resynchs	1
#endif

//==================================================================================================
//	ZKMORHP_IOThreadSlave
//==================================================================================================

ZKMORHP_IOThreadSlave::ZKMORHP_IOThreadSlave(HP_Device* inDevice)
:
	mDevice(inDevice),
//	mIOThread(reinterpret_cast<ZKMORHP_ForeignThread::ThreadRoutine>(ThreadEntry), this, ZKMORHP_ForeignThread::kMaxThreadPriority),
	mIOThread(reinterpret_cast<ZKMORHP_ForeignThread::ThreadRoutine>(ThreadEntry), this),
	mIOGuard("IOGuard"),
	mIOCycleUsage(1.0f),
	mAnchorTime(CAAudioTimeStamp::kZero),
	mFrameCounter(0),
	mIOCycleCounter(0),
	mOverloadCounter(0),
	mWorkLoopPhase(kNotRunningPhase),
	mStopWorkLoop(false)
#if Log_SchedulingLatency
	,mLatencyLog(NULL),
	mAllowedLatency(CAHostTimeBase::ConvertFromNanos(500 * 1000))
#endif
{
	#if Log_SchedulingLatency
		mLatencyLog = new CALatencyLog("/tmp/IOThreadLatencyLog", ".txt");
	#endif
}

ZKMORHP_IOThreadSlave::~ZKMORHP_IOThreadSlave()
{
	#if Log_SchedulingLatency
		delete mLatencyLog;
	#endif
}

Float32	ZKMORHP_IOThreadSlave::GetIOCycleUsage() const
{
	return mIOCycleUsage;
}

void	ZKMORHP_IOThreadSlave::SetIOCycleUsage(Float32 inIOCycleUsage)
{
	mIOCycleUsage = inIOCycleUsage;
	mIOCycleUsage = std::min(1.0f, std::max(0.0f, mIOCycleUsage));
}

UInt32	ZKMORHP_IOThreadSlave::GetWorkLoopPhase() const
{
	return mWorkLoopPhase;
}

bool	ZKMORHP_IOThreadSlave::HasBeenStopped() const
{
	return mStopWorkLoop;
}

bool	ZKMORHP_IOThreadSlave::IsCurrentThread() const
{
	return mIOThread.IsRunning() && mIOThread.IsCurrentThread();
}

void	ZKMORHP_IOThreadSlave::Start()
{
	//	the calling thread must have already locked the Guard prior to calling this method

	//	nothing to do if the IO thread is initializing or already running
	if((mWorkLoopPhase != kInitializingPhase) && (mWorkLoopPhase != kRunningPhase))
	{
		if(mWorkLoopPhase == kTeardownPhase)
		{
			//	there's nothing that can be done if this is happenning on the IO thread
			ThrowIf(mIOThread.IsCurrentThread(), CAException(kAudioHardwareIllegalOperationError), "ZKMORHP_IOThreadSlave::Start: can't restart the IO thread from inside the IO thread");
			
			//	otherwise we wait on the Guard since it is already held by this thread and this isn't the IO thread
			mIOGuard.Wait();
		}
	
		//	set the anchor time to zero so that it gets taken during the IO thread's initialization
		mAnchorTime = CAAudioTimeStamp::kZero;
		mAnchorTime.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid | kAudioTimeStampRateScalarValid;
		
		//	clear the sentinel value for stopping the IO thread in case it was set previuosly
		mStopWorkLoop = false;
		
		//	spawn a new IO thread
		//	Note that because the IOGuard is held by this thread the newly spawed IO thread
		//	won't be able to do anything since locking the IOGuard is the first thing it does.
		//	Note that we do this in a loop to be sure that the thread is actually spawned
		bool theWaitTimedOut = false;
		const UInt32 kNumberTimesToTry = 4;
		UInt32 theNumberTimesAttempted = 0;
		while((theNumberTimesAttempted < kNumberTimesToTry) && (mWorkLoopPhase == kNotRunningPhase))
		{
			//	increment the counter
			++theNumberTimesAttempted;
			
			//	spawn thre IO thread
			mIOThread.Start();
			
			//	wait for the IO thread to tell us it has started, but don't wait forever
			theWaitTimedOut = mIOGuard.WaitFor(100 * 1000 * 1000);
			if(theWaitTimedOut)
			{
				DebugMessage("ZKMORHP_IOThreadSlave::Start: waited 100ms for the IO thread to spawn");
			}
		}
		
		//	throw an exception if we totally failed to spawn an IO thread
		if(theWaitTimedOut && (theNumberTimesAttempted >= kNumberTimesToTry))
		{
			DebugMessage("ZKMORHP_IOThreadSlave::Start: totally failed to start the IO thread");
			throw CAException(kAudioHardwareIllegalOperationError);
		}
	}
}

void	ZKMORHP_IOThreadSlave::Stop()
{
	//	the calling thread must have already locked the Guard prior to calling this method
	if((mWorkLoopPhase == kInitializingPhase) || (mWorkLoopPhase == kRunningPhase))
	{
		//	set the sentinel value to stop the work loop in the IO thread
		mStopWorkLoop = true;
		
		if(!mIOThread.IsCurrentThread())
		{
			//	the current thread isn't the IO thread so this thread has to wait for
			//	the IO thread to stop before continuing
			
			//	prod the IO thread to wake up
			mIOGuard.NotifyAll();
			
			//	and wait for it to signal that it has stopped
			//  but just wait 1/2 a second -- if it hasn't returned,
			//  then it has already been stopped
			bool timedout = mIOGuard.WaitFor(500 * 1000 * 1000);
			if (timedout) {
				ZKMORLogDebug(CFSTR("ZKMORHP_IOThreadSlave::Stop timed out"));
			}
		}
	}
}

void	ZKMORHP_IOThreadSlave::Resynch(AudioTimeStamp* ioAnchorTime, bool inSignalIOThread)
{
	//	the calling thread must have already locked the Guard prior to calling this method
	if(mWorkLoopPhase == kRunningPhase)
	{
		//	get the current time
		CAAudioTimeStamp theCurrentTime;
		theCurrentTime.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid | kAudioTimeStampRateScalarValid;
		mDevice->GetCurrentTime(theCurrentTime);
		
		//	re-anchor at the given time
		if(ioAnchorTime != NULL)
		{
			Float64 theIOBufferFrameSize = mDevice->GetIOBufferFrameSize();
			if(ioAnchorTime->mSampleTime <= (theCurrentTime.mSampleTime + (2 * theIOBufferFrameSize)))
			{
				//	the new anchor time is soon, so just take it
				mAnchorTime = *ioAnchorTime;
			}
			else
			{
				//	the new anchor time is way off in the future, so calculate
				//	a different anchor time that leads to an integer number of
				//	IO cycles until the given new anchor time so that we don't
				//	accidentally miss anything important.
				AudioTimeStamp theNewAnchorTime= *ioAnchorTime;
				
				//	the sample time is easy to calculate
				Float64 theSampleTime = ioAnchorTime->mSampleTime - theCurrentTime.mSampleTime;
				theSampleTime /= theIOBufferFrameSize;
				theSampleTime = floor(theSampleTime);
				theNewAnchorTime.mSampleTime -= theIOBufferFrameSize * (theSampleTime - 1);
				
				//	use that to calculate the rest of the time stamp
				theNewAnchorTime.mFlags = kAudioTimeStampSampleTimeValid;
				mAnchorTime = CAAudioTimeStamp::kZero;
				mAnchorTime.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid | kAudioTimeStampRateScalarValid;
				mDevice->TranslateTime(theNewAnchorTime, mAnchorTime);
			}
			mFrameCounter = 0;
			
			//	set the return value
			*ioAnchorTime = mAnchorTime;
		}
		else
		{
			mAnchorTime = theCurrentTime;
			mFrameCounter = 0;
#if	Offset_For_Input
			if(mDevice->HasInputStreams())
			{
				//	the first sleep cycle as to be at least the input safety offset and a buffer's
				//	worth of time to be sure that the input data is all there
				mFrameCounter += mDevice->GetSafetyOffset(true);
			}
#endif
		}
		
		//	signal the IO thread if necessary
		if(inSignalIOThread)
		{
			mIOGuard.NotifyAll();
		}
	}
}

void	ZKMORHP_IOThreadSlave::GetCurrentPosition(AudioTimeStamp& outTime) const
{
	outTime = mAnchorTime;
	outTime.mFlags = kAudioTimeStampSampleTimeValid;
	outTime.mSampleTime += mFrameCounter;
}

bool	ZKMORHP_IOThreadSlave::WorkLoopInit()
{
	//	grab the IO guard
	bool wasLocked = mIOGuard.Lock();
	bool isInNeedOfResynch = false;

		//	initialize some stuff
	mWorkLoopPhase = kInitializingPhase;
	mIOCycleCounter = 0;
	mOverloadCounter = 0;
	CAPropertyAddress theIsRunningAddress(kAudioDevicePropertyDeviceIsRunning);
	mDevice->GetIOCycleTelemetry().IOCycleInitializeBegin(mIOCycleCounter);
	
	try {
	
		//	and signal that the IO thread is running
		mIOGuard.NotifyAll();
		
		//	initialize the work loop stopping conditions
		mStopWorkLoop = false;
		
		//	Tell the device that the IO thread has initialized. Note that we unlock around this call
		//	due to the fact that IOCycleInitialize might not return for a while because it might
		//	have to wait for the hardware to start.
		if(wasLocked)
		{
			mIOGuard.Unlock();
		}
		
		//	tell the device that the IO cycle is initializing to start the timing services
		mDevice->StartIOCycleTimingServices();
		
		//	set the device state to know the engine is running
		mDevice->IOEngineStarted();
		
		//	notify clients that the engine is running
		mDevice->PropertiesChanged(1, &theIsRunningAddress);
		
		//	re-lock the guard
		wasLocked = mIOGuard.Lock();

		//	make sure the thread is still running before moving on
		if(!mStopWorkLoop)
		{
			//	set the time constraints for the IOThread
			SetTimeConstraints();
			
			//	initialize the clock
			mDevice->EstablishIOCycleAnchorTime(mAnchorTime);
			mFrameCounter = 0;
			
#if	Offset_For_Input
			if(mDevice->HasInputStreams())
			{
				//	the first sleep cycle as to be at least the input safety offset and a buffer's
				//	worth of time to be sure that the input data is all there
				mFrameCounter += mDevice->GetSafetyOffset(true);
			}
#endif
			
			//	enter the work loop
			mWorkLoopPhase = kRunningPhase;
			isInNeedOfResynch = false;
			mDevice->GetIOCycleTelemetry().IOCycleInitializeEnd(mIOCycleCounter, mAnchorTime);
				// the work loop interation is called from another thread
//			while(!mStopWorkLoop)
//			{
//				WorkLoopIteration(isInNeedOfResynch, wasLocked);
//			}
			if (wasLocked) mIOGuard.Unlock();
		}
	}
	catch(const CAException& inException)
	{
		DebugMessageN1("ZKMORHP_IOThreadSlave::WorkLoopInit: Caught a CAException, code == %ld", (long int)inException.GetError());
	}
	catch(...)
	{
		DebugMessage("ZKMORHP_IOThreadSlave::WorkLoopInit: Caught an unknown exception.");
	}
	
	return isInNeedOfResynch;
}

void	ZKMORHP_IOThreadSlave::WorkLoopIteration(bool& isInNeedOfResynch)
{
	if (mStopWorkLoop) {
		WorkLoopTeardown();
		return;
	}
	
	try	{
		bool wasLocked = mIOGuard.Lock();
//		bool wasLocked;
		wasLocked = mIOGuard.Try(wasLocked);
		
		//	get the current time
		AudioTimeStamp theCurrentTime;
		mDevice->GetCurrentTime(theCurrentTime);
		
			//	increment the counter
			++mIOCycleCounter;
			
		//	do IO if the thread wasn't stopped
		if(!mStopWorkLoop)
		{
			if(theCurrentTime.mSampleTime >= (mAnchorTime.mSampleTime + mFrameCounter))
			{
				//	increment the frame counter
				mFrameCounter += mDevice->GetIOBufferFrameSize();
			
				//	the new cycle is starting
				mDevice->GetIOCycleTelemetry().IOCycleWorkLoopBegin(mIOCycleCounter, theCurrentTime);
				if(mDevice->UpdateIOCycleTimingServices())
				{
					//	something unexpected happened with the time stamp, so resynch prior to doing IO
					AudioTimeStamp theNewAnchor = CAAudioTimeStamp::kZero;
					theNewAnchor.mSampleTime = 0;
					theNewAnchor.mHostTime = 0;
					theNewAnchor.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
					if(mDevice->EstablishIOCycleAnchorTime(theNewAnchor))
					{
						Resynch(&theNewAnchor, false);
					}
					else
					{
						Resynch(NULL, false);
					}
					
					//	re-get the current time too
					mDevice->GetCurrentTime(theCurrentTime);
				}
			
				//	do the IO
				isInNeedOfResynch = PerformIO(theCurrentTime);
			}
		}
		
		//	calculate the next wake up time
		AudioTimeStamp theNextWakeUpTime = CAAudioTimeStamp::kZero;
		theNextWakeUpTime.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
//		bool wasLocked = false;
//		bool wasLocked = mIOGuard.Lock();
		if(CalculateNextWakeUpTime(theCurrentTime, theNextWakeUpTime, isInNeedOfResynch, wasLocked))
		{
			mDevice->GetIOCycleTelemetry().IOCycleWorkLoopEnd(mIOCycleCounter, theCurrentTime, theNextWakeUpTime);
		}
		
		//	execute any deferred commands
		mDevice->ExecuteAllCommands();
		if (wasLocked) mIOGuard.Unlock();
	} 
	catch(const CAException& inException)
	{
		DebugMessageN1("ZKMORHP_IOThreadSlave::WorkLoopIteration: Caught a CAException, code == %ld", (long int)inException.GetError());
	}
	catch(...)
	{
		DebugMessage("ZKMORHP_IOThreadSlave::WorkLoopIteration: Caught an unknown exception.");
	}
}

void	ZKMORHP_IOThreadSlave::WorkLoopTeardown()
{
	// The other thread holds the lock during teardown
	try {
		mWorkLoopPhase = kTeardownPhase;
		mDevice->GetIOCycleTelemetry().IOCycleTeardownBegin(mIOCycleCounter);

		//	the work loop has finished, clear the time constraints
		ClearTimeConstraints();
		
		//	tell the device that the IO thread is torn down
		mDevice->StopIOCycleTimingServices();
	}
	catch(const CAException& inException)
	{
		DebugMessageN1("ZKMORHP_IOThreadSlave::WorkLoopTeardown: Caught a CAException, code == %ld", (long int)inException.GetError());
	}
	catch(...)
	{
		DebugMessage("ZKMORHP_IOThreadSlave::WorkLoopTeardown: Caught an unknown exception.");
	}
	
	//	set the device state to know the engine has stopped
	mDevice->IOEngineStopped();
		
	//	Notify clients that the IO thread is stopping
	CAPropertyAddress theIsRunningAddress(kAudioDevicePropertyDeviceIsRunning);
	mDevice->PropertiesChanged(1, &theIsRunningAddress);

	mDevice->GetIOCycleTelemetry().IOCycleTeardownEnd(mIOCycleCounter);
	mWorkLoopPhase = kNotRunningPhase;
	mIOGuard.NotifyAll();
	mIOCycleCounter = 0;
}


void	ZKMORHP_IOThreadSlave::WorkLoop()
{
	//	grab the IO guard
	bool wasLocked = mIOGuard.Lock();
	
	//	initialize some stuff
	mWorkLoopPhase = kInitializingPhase;
	mIOCycleCounter = 0;
	mOverloadCounter = 0;
	CAPropertyAddress theIsRunningAddress(kAudioDevicePropertyDeviceIsRunning);
	mDevice->GetIOCycleTelemetry().IOCycleInitializeBegin(mIOCycleCounter);
		
	try
	{
		//	and signal that the IO thread is running
		mIOGuard.NotifyAll();
		
		//	initialize the work loop stopping conditions
		mStopWorkLoop = false;
		
		//	Tell the device that the IO thread has initialized. Note that we unlock around this call
		//	due to the fact that IOCycleInitialize might not return for a while because it might
		//	have to wait for the hardware to start.
		if(wasLocked)
		{
			mIOGuard.Unlock();
		}
		
		//	tell the device that the IO cycle is initializing to start the timing services
		mDevice->StartIOCycleTimingServices();
		
		//	set the device state to know the engine is running
		mDevice->IOEngineStarted();
		
		//	notify clients that the engine is running
		mDevice->PropertiesChanged(1, &theIsRunningAddress);
		
		//	re-lock the guard
		wasLocked = mIOGuard.Lock();

		//	make sure the thread is still running before moving on
		if(!mStopWorkLoop)
		{
			//	set the time constraints for the IOThread
			SetTimeConstraints();
			
			//	initialize the clock
			mDevice->EstablishIOCycleAnchorTime(mAnchorTime);
			mFrameCounter = 0;
			
#if	Offset_For_Input
			if(mDevice->HasInputStreams())
			{
				//	the first sleep cycle as to be at least the input safety offset and a buffer's
				//	worth of time to be sure that the input data is all there
				mFrameCounter += mDevice->GetSafetyOffset(true);
			}
#endif
			
			//	enter the work loop
			mWorkLoopPhase = kRunningPhase;
			bool isInNeedOfResynch = false;
			mDevice->GetIOCycleTelemetry().IOCycleInitializeEnd(mIOCycleCounter, mAnchorTime);
			while(!mStopWorkLoop)
			{
				//	get the current time
				AudioTimeStamp theCurrentTime;
				mDevice->GetCurrentTime(theCurrentTime);
				
				//	calculate the next wake up time
				AudioTimeStamp theNextWakeUpTime = CAAudioTimeStamp::kZero;
				theNextWakeUpTime.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
				if(CalculateNextWakeUpTime(theCurrentTime, theNextWakeUpTime, isInNeedOfResynch, wasLocked))
				{
					//	sleep until the  next wake up time
					mDevice->GetIOCycleTelemetry().IOCycleWorkLoopEnd(mIOCycleCounter, theCurrentTime, theNextWakeUpTime);
					mIOGuard.WaitUntil(CAHostTimeBase::ConvertToNanos(theNextWakeUpTime.mHostTime));
					
					//	increment the counter
					++mIOCycleCounter;
					
					//	do IO if the thread wasn't stopped
					if(!mStopWorkLoop)
					{
						//	get the current time
						mDevice->GetCurrentTime(theCurrentTime);
						
						#if Log_SchedulingLatency
							//	check to see if we have incurred a large scheduling latency
							if(theCurrentTime.mHostTime > (theNextWakeUpTime.mHostTime + mAllowedLatency))
							{
								//	log it
								mLatencyLog->Capture(theNextWakeUpTime.mHostTime - mAllowedLatency, theCurrentTime.mHostTime, true);
								
								//	print how late we are
								DebugMessageN1("HP_IOThread::WorkLoop: woke up late by %f milliseconds", ((Float64)CAHostTimeBase::ConvertToNanos(theCurrentTime.mHostTime - theNextWakeUpTime.mHostTime)) / (1000.0 * 1000.0));
							}
						#endif
						
						if(theCurrentTime.mSampleTime >= (mAnchorTime.mSampleTime + mFrameCounter))
						{
							//	increment the frame counter
							mFrameCounter += mDevice->GetIOBufferFrameSize();
						
							//	the new cycle is starting
							mDevice->GetIOCycleTelemetry().IOCycleWorkLoopBegin(mIOCycleCounter, theCurrentTime);
							if(mDevice->UpdateIOCycleTimingServices())
							{
								//	something unexpected happenned with the time stamp, so resynch prior to doing IO
								AudioTimeStamp theNewAnchor = CAAudioTimeStamp::kZero;
								theNewAnchor.mSampleTime = 0;
								theNewAnchor.mHostTime = 0;
								theNewAnchor.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
								if(mDevice->EstablishIOCycleAnchorTime(theNewAnchor))
								{
									Resynch(&theNewAnchor, false);
								}
								else
								{
									Resynch(NULL, false);
								}
								
								//	re-get the current time too
								mDevice->GetCurrentTime(theCurrentTime);
							}
						
							//	do the IO
							isInNeedOfResynch = PerformIO(theCurrentTime);
						}
					}
				}
				else
				{
					//	calculating the next wake up time failed, so we just stop everything (which
					//	will get picked up when the commands are executed
					mDevice->ClearAllCommands();
					mDevice->Do_StopAllIOProcs();
				}
				
				//	execute any deferred commands
				mDevice->ExecuteAllCommands();
			}
		}
	
		mWorkLoopPhase = kTeardownPhase;
		mDevice->GetIOCycleTelemetry().IOCycleTeardownBegin(mIOCycleCounter);

		//	the work loop has finished, clear the time constraints
		ClearTimeConstraints();
		
		//	tell the device that the IO thread is torn down
		mDevice->StopIOCycleTimingServices();
	}
	catch(const CAException& inException)
	{
		DebugMessageN1("HP_IOThread::WorkLoop: Caught a CAException, code == %ld", (long int)inException.GetError());
	}
	catch(...)
	{
		DebugMessage("HP_IOThread::WorkLoop: Caught an unknown exception.");
	}
	
	//	set the device state to know the engine has stopped
	mDevice->IOEngineStopped();
		
	//	Notify clients that the IO thread is stopping. Note that we unlock around this call
	//	due to the fact that clients might want to call back into the HAL.
	if(wasLocked)
	{
		mIOGuard.Unlock();
	}

	//	Notify clients that the IO thread is stopping
	mDevice->PropertiesChanged(1, &theIsRunningAddress);
		
	//	re-lock the guard
	wasLocked = mIOGuard.Lock();

	mDevice->GetIOCycleTelemetry().IOCycleTeardownEnd(mIOCycleCounter);
	mWorkLoopPhase = kNotRunningPhase;
	mIOGuard.NotifyAll();
	mIOCycleCounter = 0;
	
	if(wasLocked)
	{
		mIOGuard.Unlock();
	}
}

void	ZKMORHP_IOThreadSlave::SetTimeConstraints()
{
	UInt64 thePeriod = 0;
	UInt32 theQuanta = 0;
	mDevice->CalculateIOThreadTimeConstraints(thePeriod, theQuanta);
	mIOThread.SetTimeConstraints(static_cast<UInt32>(thePeriod), theQuanta, static_cast<UInt32>(thePeriod), true);
}

void	ZKMORHP_IOThreadSlave::ClearTimeConstraints()
{
	mIOThread.ClearTimeConstraints();
}

bool	ZKMORHP_IOThreadSlave::CalculateNextWakeUpTime(const AudioTimeStamp& inCurrentTime, AudioTimeStamp& outNextWakeUpTime, bool inMustResynch, bool& inIOGuardWasLocked)
{
	bool theAnswer = true;
	
//	static const Float64 kOverloadThreshold = 0.050;
	static const Float64 kOverloadThreshold = 0.000;
	bool isDone = false;
	AudioTimeStamp theCurrentTime = inCurrentTime;
	
	int theNumberIterations = 0;
	while(!isDone)
	{
		++theNumberIterations;
		Float64 theIOBufferFrameSize = mDevice->GetIOBufferFrameSize();
		
		//	set up the outNextWakeUpTime
		outNextWakeUpTime = CAAudioTimeStamp::kZero;
		outNextWakeUpTime.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
		
		//	set up the overload time
		AudioTimeStamp theOverloadTime = CAAudioTimeStamp::kZero;
		theOverloadTime.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
		
		//	calculate the sample time for the next wake up time
		AudioTimeStamp theSampleTime = mAnchorTime;
		theSampleTime.mFlags = kAudioTimeStampSampleTimeValid;
		theSampleTime.mSampleTime += mFrameCounter;
		theSampleTime.mSampleTime += theIOBufferFrameSize;
		
		//	translate that to a host time
		mDevice->TranslateTime(theSampleTime, outNextWakeUpTime);
		
		//	calculate the overload time
		Float64 theReservedAmount = std::max(0.0, mIOCycleUsage - kOverloadThreshold);
		theSampleTime = mAnchorTime;
		theSampleTime.mFlags = kAudioTimeStampSampleTimeValid;
		theSampleTime.mSampleTime += mFrameCounter;
		theSampleTime.mSampleTime += theReservedAmount * theIOBufferFrameSize;
		
		//	translate that to a host time
		mDevice->TranslateTime(theSampleTime, theOverloadTime);
		
		if(inMustResynch || (theCurrentTime.mHostTime >= theOverloadTime.mHostTime))
		{
			//	tell the device what happenned
			mDevice->GetIOCycleTelemetry().IOCycleWorkLoopOverloadBegin(mIOCycleCounter, theCurrentTime, theOverloadTime);
			
			//	the current time is beyond the overload time, have to resynchronize
			#if Log_Resynchs
				if(inMustResynch)
				{
					DebugMessageN1("ZKMORHP_IOThreadSlave::CalculateNextWakeUpTime: resynch was forced %d", theNumberIterations);
				}
				else
				{
					DebugMessageN1("ZKMORHP_IOThreadSlave::CalculateNextWakeUpTime: wake up time is in the past... resynching %d", theNumberIterations);
					DebugMessageN3("           Now: %qd Overload: %qd Difference: %qd", CAHostTimeBase::ConvertToNanos(theCurrentTime.mHostTime), CAHostTimeBase::ConvertToNanos(theOverloadTime.mHostTime), CAHostTimeBase::ConvertToNanos(theCurrentTime.mHostTime - theOverloadTime.mHostTime));
				}
			#endif
			
			//	notify clients that the overload has taken place
			if(inIOGuardWasLocked)
			{
				mIOGuard.Unlock();
			}
			CAPropertyAddress theOverloadAddress(kAudioDeviceProcessorOverload);
			mDevice->PropertiesChanged(1, &theOverloadAddress);
			inIOGuardWasLocked = mIOGuard.Lock();

			//	re-anchor at the current time
			theCurrentTime.mSampleTime = 0;
			theCurrentTime.mHostTime = 0;
			if(mDevice->EstablishIOCycleAnchorTime(theCurrentTime))
			{
				Resynch(&theCurrentTime, false);
			}
			else
			{
				theAnswer = false;
				isDone = true;
			}
			
			//	reset the forced resynch flag
			inMustResynch = false;
			mDevice->GetIOCycleTelemetry().IOCycleWorkLoopOverloadEnd(mIOCycleCounter, mAnchorTime);
		}
		else
		{
			//	still within the limits
			isDone = true;
		}
	}
	
	//  adjust the counter depending on what happenned
	if(theNumberIterations > 1)
	{
		//  we went through the calculation more than once, which means an overload happenned
		++mOverloadCounter;
	}
	else
	{
		//  only did the calculation once, so no overload occurred
		mOverloadCounter = 0;
	}
	
	return theAnswer;
}

bool	ZKMORHP_IOThreadSlave::PerformIO(const AudioTimeStamp& inCurrentTime)
{
	//	The input head is at the anchor plus the sample counter minus one
	//	buffer's worth of frames minus the safety offset.
	AudioTimeStamp theInputTime = CAAudioTimeStamp::kZero;
	if(mDevice->HasInputStreams())
	{
		AudioTimeStamp theInputFrameTime;
		theInputFrameTime = mAnchorTime;
		theInputFrameTime.mFlags = kAudioTimeStampSampleTimeValid;
		theInputFrameTime.mSampleTime += mFrameCounter;
		theInputFrameTime.mSampleTime -= mDevice->GetSafetyOffset(true);
		theInputFrameTime.mSampleTime -= mDevice->GetIOBufferFrameSize();
		
		//	use that to figure the corresponding host time
		theInputTime.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
		mDevice->TranslateTime(theInputFrameTime, theInputTime);
	}

	//	The output head is at the anchor plus the sample counter
	//	plus one buffer's worth of frames plus the safety offset
	AudioTimeStamp theOutputTime = CAAudioTimeStamp::kZero;
	if(mDevice->HasOutputStreams())
	{
		//	calculate the head position in frames
		AudioTimeStamp theOutputFrameTime;
		theOutputFrameTime = mAnchorTime;
		theOutputFrameTime.mFlags = kAudioTimeStampSampleTimeValid;
		theOutputFrameTime.mSampleTime += mFrameCounter;
		theOutputFrameTime.mSampleTime += mDevice->GetSafetyOffset(false);
		theOutputFrameTime.mSampleTime += (mIOCycleUsage * mDevice->GetIOBufferFrameSize());
		
		//	use that to figure the corresponding host time
		theOutputTime.mFlags = kAudioTimeStampSampleTimeValid + kAudioTimeStampHostTimeValid + kAudioTimeStampRateScalarValid;
		mDevice->TranslateTime(theOutputFrameTime, theOutputTime);
	}
	
	//	unlike CallIOProcs, this routine returns whether or not the caller needs to resynch.
	return !mDevice->CallIOProcs(inCurrentTime, theInputTime, theOutputTime);
}

void*	ZKMORHP_IOThreadSlave::ThreadEntry(ZKMORHP_IOThreadSlave* inIOThread)
{
	inIOThread->WorkLoop();
	return NULL;
}
