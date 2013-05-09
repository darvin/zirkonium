/*
 *  ZKMORHALPlugIn.h
 *  Cushion
 *
 *  Created by Chandrasekhar Ramakrishnan on 26.02.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __ZKMORHALPlugIn_H__
#define __ZKMORHALPlugIn_H__

#include <Carbon/Carbon.h>
#include <CoreAudio/CoreAudio.h>
#include <CoreAudio/AudioHardwarePlugin.h>
#include <IOKit/audio/IOAudioTypes.h>
#include <AudioUnit/AudioUnit.h>
#include <map>
#include "CAAudioTimeStamp.h"
#include "AUOutputBL.h"

#include <CoreAudio/AudioHardwarePlugin.h>

#ifdef __cplusplus
extern "C" {
#endif

struct ZKMORHALPlugInImpl;
/// 
///  ZKMORHALPlugIn
///
///  The struct def for a HAL plug-in. Users should subclass ZKMORHALPlugInImpl to create the plug-in they want and should
///  initialize the reference in their plug-in creation function. See the Cushion Plug-In for an example.
///
///  Subclasses need to override at least the following functions:
///		- InitializeDeviceOutput()
///		- ReadInputFromWrappedDevice()
///		- StartWrappedDevice()
///		- StopWrappedDevice()
/// 
///  and initialze the variables:
///		- mDeviceName 
///		- mDeviceManu
///		- mDeviceUID
///		- mModelUID
///		- mConfigApplication
///		- mDefaultsDomain
///
typedef struct {
	AudioHardwarePlugInInterface*	mAHInterface;
	CFUUIDRef						mFactoryID;
	UInt32							mRefCount;
	ZKMORHALPlugInImpl*				mPlugInImpl;
} ZKMORHALPlugIn;

#define ZKMCNDebugPrintf printf

#ifdef __cplusplus
}
#endif


using namespace std;
/// 
///  ZKMORHALPlugInImpl
///
///  A minimal implementation of the plugin interface. Doesn't do anything except look like a device to the HAL. You can
///  subclass this to make a functioning plugin. See also ZKMORHALPlugInImplSycamore.
///
class ZKMORHALPlugInImpl {

public:	
//  COM API
	static HRESULT	PlugInQueryInterface(void * obj, REFIID iid, LPVOID *ppv);
	static ULONG	PlugInAddRef(void * obj);
	
//  HAL Plug-in API
	static OSStatus	Initialize(AudioHardwarePlugInRef inSelf);
	static OSStatus Teardown(AudioHardwarePlugInRef inSelf);

	static OSStatus DeviceAddIOProc(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc, void* data);
	static OSStatus DeviceRemoveIOProc(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc);

	static OSStatus DeviceStart(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc);
	static OSStatus DeviceStop(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc proc);

	static OSStatus DeviceRead(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, const AudioTimeStamp* inStartTime, AudioBufferList* outData);

	static OSStatus DeviceGetCurrentTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioTimeStamp* outTime);
	static OSStatus DeviceTranslateTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, const AudioTimeStamp* inTime, AudioTimeStamp* outTime);

	static OSStatus	DeviceGetPropertyInfo(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable);
	static OSStatus DeviceGetProperty(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData);
	static OSStatus DeviceSetProperty(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, const AudioTimeStamp* inWhen, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);

	static OSStatus StreamGetPropertyInfo(AudioHardwarePlugInRef inSelf, AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable);
	static OSStatus StreamGetProperty(AudioHardwarePlugInRef inSelf, AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData);
	static OSStatus	StreamSetProperty(AudioHardwarePlugInRef inSelf, AudioStreamID inStream, const AudioTimeStamp* inWhen, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);

	static OSStatus DeviceStartAtTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioDeviceIOProc inProc, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags);
	static OSStatus	DeviceGetNearestStartTime(AudioHardwarePlugInRef inSelf, AudioDeviceID inDevice, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags);

public:	
	static ZKMORHALPlugInImpl* GetPlugInImpl(AudioHardwarePlugInRef plugIn);
	
	//  CTOR / DTOR
	ZKMORHALPlugInImpl(AudioHardwarePlugInRef plugIn);
	virtual ~ZKMORHALPlugInImpl();
	
	//  Calls the clients and asks them to generate audio
	OSStatus	RenderClients(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames, AudioBufferList *ioData);

protected:
// HAL Plug-in API
	virtual OSStatus	Initialize();
	virtual OSStatus	Teardown();

	virtual OSStatus	DeviceAddIOProc(AudioDeviceID inDevice, AudioDeviceIOProc proc, void* data);
	virtual OSStatus	DeviceRemoveIOProc(AudioDeviceID inDevice, AudioDeviceIOProc proc);

	virtual OSStatus	DeviceStart(AudioDeviceID inDevice, AudioDeviceIOProc proc);
	virtual OSStatus	DeviceStop(AudioDeviceID inDevice, AudioDeviceIOProc proc);
	
	virtual OSStatus	DeviceRead(AudioDeviceID inDevice, const AudioTimeStamp* inStartTime, AudioBufferList* outData);

	virtual OSStatus	DeviceGetCurrentTime(AudioDeviceID inDevice, AudioTimeStamp* outTime);
	virtual OSStatus	DeviceTranslateTime(AudioDeviceID inDevice, const AudioTimeStamp* inTime, AudioTimeStamp* outTime);
	
	virtual OSStatus	DeviceGetPropertyInfo(AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable);
	virtual OSStatus	DeviceGetProperty(AudioDeviceID inDevice, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData);
	virtual OSStatus	DeviceSetProperty(AudioDeviceID inDevice, const AudioTimeStamp* inWhen, UInt32 inChannel, Boolean isInput, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);
	
	virtual OSStatus	StreamGetPropertyInfo(AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* outSize, Boolean* outWritable);
	virtual OSStatus	StreamGetProperty(AudioStreamID inStream, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32* ioPropertyDataSize, void* outPropertyData);
	virtual OSStatus	StreamSetProperty(AudioStreamID inStream, const AudioTimeStamp* inWhen, UInt32 inChannel, AudioDevicePropertyID inPropertyID, UInt32 inPropertyDataSize, const void* inPropertyData);
	
	virtual OSStatus	DeviceStartAtTime(AudioDeviceID inDevice, AudioDeviceIOProc inProc, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags);
	virtual OSStatus	DeviceGetNearestStartTime(AudioDeviceID inDevice, AudioTimeStamp* ioRequestedStartTime, UInt32 inFlags);
	
protected: 
//  Internal Data Structures
	struct IOProcState {
		AudioDeviceIOProc	mProc;
		void*				mRefCon;
		bool				mIsRunning;
		
		IOProcState() : mProc(NULL), mRefCon(NULL), mIsRunning(false) { }
		IOProcState(AudioDeviceIOProc proc, void* refCon) : mProc(proc), mRefCon(refCon), mIsRunning(false) { }
	};
	
	typedef std::map<AudioDeviceIOProc, IOProcState> ZKMORIOProcMap;
	
protected:
//  Internal Functions

	//  Accessors
	virtual UInt32				BufferSizeInFrames();
	virtual AudioValueRange		BufferSizeRangeInFrames();
	virtual Float64				GetSampleRate();
	
	//  Actions
	virtual void		InitializeWrappedDevice();	
	virtual void		IncrementRunningIOProcCount();
	virtual void		DecrementRunningIOProcCount();
	virtual void		ReadWrappedDeviceUID();
	
	virtual OSStatus	CreateStreams();
	virtual OSStatus	DestroyStreams();
	virtual	void		SetNumberOfChannels(unsigned numberOfInputs, unsigned numberOfOutputs);

		// Subclass Overrides
	virtual void		InitializeDeviceOutput() = 0;
	virtual void		StartWrappedDevice() = 0;
	virtual void		StopWrappedDevice() = 0;
	virtual void		ReadInputFromWrappedDevice(const AudioTimeStamp *inTimeStamp, UInt32 inNumberFrames) = 0;

	//  Queries
	virtual bool		IsRunning();
	virtual bool		IsAlive();
	virtual bool		IsWrappedDeviceInitialized();

		// Subclass Overrides
	virtual bool		IsDeviceOutputInitialized() = 0;

protected:
	//  PlugIn State
	AudioHardwarePlugInRef	mPlugIn;

	UInt32			mNumberOfInputChannels;
	UInt32			mNumberOfOutputChannels;
	Float64			mSampleRate;

	SInt32			mRunningIOProcCount;
	bool			mIsInitialized;

	AudioDeviceID	mDeviceID;
		// or should I use std::vector ?
	AudioStreamID*	mOutputStreamIDs;
	AudioStreamID*	mInputStreamIDs;

		/// the underlying device this interface uses
	AudioDeviceID	mWrappedDevice;	
	CFStringRef 	mWrappedDeviceUID;
	UInt32			mWrappedDeviceInputSafteyOffset;
	UInt32			mWrappedDeviceOutputSafteyOffset;
	UInt32			mWrappedDeviceBufferFrameSize;
	
	CFStringRef		mDeviceName;
	CFStringRef		mDeviceManu;
	CFStringRef		mDeviceUID;
	CFStringRef		mModelUID;
	CFStringRef		mConfigApplication;
	CFStringRef		mDefaultsDomain;
	
	ZKMORIOProcMap	mIOProcs;
	
		// getting input from the device
	AUOutputBL*			mInputBL;
};

#endif