/*
 *  ZKMORHP_Device.h
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 28.02.08.
 *  Copyright 2008 Illposed Software. All rights reserved.
 *
 */

#if !defined(__ZKMORHP_Device_h__)
#define __ZKMORHP_Device_h__

//=============================================================================
//	Includes
//=============================================================================
//  Framework Includes
#include <CoreAudio/CoreAudio.h>

//	Super Class Includes
#include "HP_Device.h"

//  System Includes
#include <IOKit/IOKitLib.h>

//=============================================================================
//	Types
//=============================================================================

class	HP_DeviceControlProperty;
class	HP_HogMode;
class	HP_IOProc;
class   HP_IOThread;
class	ZKMORHP_PlugIn;
class   ZKMORHP_Stream;

//=============================================================================
//	ZKMORHP_Device
//=============================================================================

class ZKMORHP_Device
:
	public HP_Device
{

//	Construction/Destruction
public:
								ZKMORHP_Device(AudioDeviceID inAudioDeviceID, ZKMORHP_PlugIn* inPlugIn, UInt32 numInputChannels, UInt32 numOutputChannels);
	virtual						~ZKMORHP_Device();

	virtual void				Initialize();
	virtual void				Teardown();
	virtual void				Finalize();

protected:
	ZKMORHP_PlugIn*				mPlugIn;
	
//	Attributes
public:
	ZKMORHP_PlugIn*				GetPlugIn() const { return mPlugIn; }
	virtual CFStringRef			CopyDeviceName() const;
	virtual CFStringRef			CopyDeviceManufacturerName() const;
	virtual CFStringRef			CopyDeviceUID() const;
	virtual bool				HogModeIsOwnedBySelf() const;
	virtual bool				HogModeIsOwnedBySelfOrIsFree() const;
	virtual void				HogModeStateChanged();

private:
	HP_HogMode*					mHogMode;

//	Property Access
public:
	virtual bool				HasProperty(const AudioObjectPropertyAddress& inAddress) const;
	virtual bool				IsPropertySettable(const AudioObjectPropertyAddress& inAddress) const;
	virtual UInt32				GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const;
	virtual void				GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const;
	virtual void				SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen);

protected:
	virtual void				PropertyListenerAdded(const AudioObjectPropertyAddress& inAddress);

//	Command Management
protected:
	virtual bool				IsSafeToExecuteCommand();
	virtual bool				StartCommandExecution(void** outSavedCommandState);
	virtual void				FinishCommandExecution(void* inSavedCommandState);

//	IOProc Management
public:
	virtual void				Do_StartIOProc(AudioDeviceIOProc inProc);
	virtual void				Do_StartIOProcAtTime(AudioDeviceIOProc inProc, AudioTimeStamp& ioStartTime, UInt32 inStartTimeFlags);

//  IO Management
public:
	virtual CAGuard*			GetIOGuard();
	virtual bool				CallIOProcs(const AudioTimeStamp& inCurrentTime, const AudioTimeStamp& inInputTime, const AudioTimeStamp& inOutputTime);
	virtual bool				CallIOProcs(const AudioTimeStamp* inTimeStamp, UInt32 inNumberFrames, AudioBufferList				*ioData);
	
protected:
	virtual void				StartIOEngine();
	virtual void				StartIOEngineAtTime(const AudioTimeStamp& inStartTime, UInt32 inStartTimeFlags);
	virtual void				StopIOEngine();
	
	virtual void				StartHardware();
	virtual void				StopHardware();

	void						StartIOCycle();
	void						PreProcessInputData(const AudioTimeStamp& inInputTime);
	bool						ReadInputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID);
	void						PostProcessInputData(const AudioTimeStamp& inInputTime);
	virtual void				PreProcessOutputData(const AudioTimeStamp& inOuputTime, HP_IOProc& inIOProc);
	virtual bool				WriteOutputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID);
	virtual bool				WriteOutputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID, AudioBufferList* ioData);
	void						FinishIOCycle();
	
	//  Removed references to the IO Thread -- I piggyback on another devices thread
//	HP_IOThread*				mIOThread;

//	IO Cycle Telemetry Support
public:
	virtual UInt32				GetIOCycleNumber() const;

//	Time Management
public:
	virtual void				GetCurrentTime(AudioTimeStamp& outTime);
	virtual void				SafeGetCurrentTime(AudioTimeStamp& outTime);
	virtual void				TranslateTime(const AudioTimeStamp& inTime, AudioTimeStamp& outTime);
	virtual void				GetNearestStartTime(AudioTimeStamp& ioRequestedStartTime, UInt32 inFlags);
	
	virtual void				StartIOCycleTimingServices();
	virtual bool				UpdateIOCycleTimingServices();
	virtual void				StopIOCycleTimingServices();

private:
	UInt64						mAnchorHostTime;
	
//  Stream Management
private:
	void						CreateStreams();
	void						ReleaseStreams();
	void						RefreshAvailableStreamFormats();

//  Controls
protected:
	void						CreateControls();
	void						ReleaseControls();
	
	static bool					IsControlRelatedProperty(AudioObjectPropertySelector inSelector);

private:
	bool						mControlsInitialized;
	HP_DeviceControlProperty*	mControlProperty;
	
//  Sycamore State
public:
	virtual Float64				GetSampleRate() const { return mSampleRate; }
	
protected:
	UInt32						mNumberOfInputChannels;
	UInt32						mNumberOfOutputChannels;
	Float64						mSampleRate;
};

#endif
