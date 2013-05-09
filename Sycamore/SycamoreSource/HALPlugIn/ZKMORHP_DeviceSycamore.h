//
//  ZKMORHP_DeviceSycamore.h
//  Cushion
//
//  Created by C. Ramakrishnan on 29.02.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//
//  The ZKMORHP_DeviceSycamore is an AudioHardwarePlugIn device that
//  wraps an underlying device using Sycamore functionality.
//  

#ifndef __ZKMORHP_DeviceSycamore_H__
#define __ZKMORHP_DeviceSycamore_H__

#include "ZKMORHP_Device.h"

#ifdef __SYNCRETISM__
#import <Syncretism/Syncretism.h>
#else
#import <Sycamore/Sycamore.h>
#endif

@class ZKMORDeviceShim;
/// 
///  ZKMORHALPlugInImplSycamore
///
///  Extends the ZKMORHALPlugInImpl to use the Sycamore Device Output to communicate with the output device.
///
class ZKMORHP_DeviceSycamore : public ZKMORHP_Device {

public:	

//  CTOR / DTOR
					ZKMORHP_DeviceSycamore(AudioDeviceID inAudioDeviceID, ZKMORHP_PlugIn* inPlugIn, UInt32 numInputChannels, UInt32 numOutputChannels, CFStringRef deviceName, CFStringRef manuName, CFStringRef deviceUID, CFStringRef modelUID, CFStringRef defaultsDomain);
	virtual			~ZKMORHP_DeviceSycamore();
	
protected:
//  Device Wrapping State
	virtual void	ReadWrappedDeviceUID();
	virtual void	InitializeWrappedDevice();

public:
//  Property Access
	void			GetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32& ioDataSize, void* outData) const;
	void			SetPropertyData(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData, UInt32 inDataSize, const void* inData, const AudioTimeStamp* inWhen);
	
    UInt32          GetPropertyDataSize(const AudioObjectPropertyAddress& inAddress, UInt32 inQualifierDataSize, const void* inQualifierData) const;
    
	bool			CanBeDefaultDevice(bool inIsInput, bool inIsSystem) const;

//  Actions
	void			Do_StartIOProc(AudioDeviceIOProc inProc);
	void			Do_StartIOProcAtTime(AudioDeviceIOProc inProc, AudioTimeStamp& ioStartTime, UInt32 inStartTimeFlags);
	void			StartHardware();
	void			StopHardware();
	
//  Getting Data
	void			CopyOutputData(AudioBufferList *ioData);
	
protected:
	bool			ReadInputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID);
	bool			WriteOutputData(const AudioTimeStamp& inStartTime, UInt32 inBufferSetID);
	
protected:
	//  Actions
	virtual void	InitializeDeviceOutput();
	virtual void	StartWrappedDevice();
	virtual void	StopWrappedDevice();
	virtual void	ReadInputFromWrappedDevice(const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames);
	virtual void	SetNumberOfChannels(unsigned numberOfInputs, unsigned numberOfOutputs);
	//  Subclass Overrides
	virtual void	PatchOutputGraph();

	//  Queries
	virtual bool	IsWrappedDeviceInitialized() const;
	virtual bool	IsDeviceOutputInitialized() const { return mDeviceOutput != NULL; }
	
	//  Accessors
	virtual UInt32				BufferSizeInFrames() const;
	virtual AudioValueRange		BufferSizeRangeInFrames() const;
	virtual Float64				GetSampleRate() const;
	
public:
	// Time Services
	void GetCurrentTime(AudioTimeStamp& outTime);
	void TranslateTime(const AudioTimeStamp& inTime, AudioTimeStamp& outTime);

protected:
		/// the underlying device this interface uses
	AudioDeviceID	mWrappedDevice;	
	CFStringRef 	mWrappedDeviceUID;
	UInt32			mWrappedDeviceInputSafteyOffset;
	UInt32			mWrappedDeviceOutputSafteyOffset;
	UInt32			mWrappedDeviceBufferFrameSize;
		/// where to read the device UID from
	CFStringRef		mDefaultsDomain;
	
		// the graph this device runs
	ZKMORDeviceOutput*	mDeviceOutput;
	ZKMORGraph*			mGraph;
	ZKMORMixerMatrix*	mMixerMatrix;
	ZKMORDeviceShim*	mConduitShim;
	
		// getting input from the device
	ZKMORDeviceInput*	mDeviceInput;
	ZKMORRenderFunction mInputRenderFunction;
};

///
///  ZKMORDeviceShim
/// 
///  A way to insert data from the device into a conduit graph.
///
///  The RenderFunction just calls into the device to render its clients
///
@interface ZKMORDeviceShim : ZKMORConduit {
@public
	ZKMORHP_DeviceSycamore*	mPlugInImpl;
}

- (id)initWithImpl:(ZKMORHP_DeviceSycamore *)plugInImpl;

@end


#endif
